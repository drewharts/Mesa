//
//  ProfileTabIconViewModel.swift
//  loc
//
//  Supplies the Profile tab's icon: the signed-in user's cached profile photo rendered as a
//  small circle (with a ring when selected). Stays nil until a photo is available so the
//  tab falls back to the system person icon.
//

import UIKit
import Combine

@MainActor
final class ProfileTabIconViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var normalIcon: UIImage?
    @Published private(set) var selectedIcon: UIImage?

    // MARK: - Dependencies

    private let photoCache = ProfilePhotoCache.shared
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Starts following the profile's photo URL and the shared photo cache.
    init(profileViewModel: ProfileViewModel) {
        profileViewModel.$user
            .map { (user: ProfileData?) -> PhotoSource? in
                guard let user, let url = user.profilePhotoURL else { return nil }
                return PhotoSource(userId: user.id, url: url)
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] source in self?.photoSourceChanged(source) }
            .store(in: &cancellables)
    }

    // MARK: - Private

    /// The signed-in user's photo location.
    private struct PhotoSource: Equatable {
        let userId: String
        let url: URL
    }

    /// Clears the icon when the user has no photo, otherwise loads it and renders both variants.
    private func photoSourceChanged(_ source: PhotoSource?) {
        loadTask?.cancel()
        guard let source else {
            normalIcon = nil
            selectedIcon = nil
            return
        }
        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.photoCache.loadPhoto(userId: source.userId, photoURL: source.url)
            guard !Task.isCancelled, let photo = self.photoCache.photo(for: source.userId) else { return }
            self.normalIcon = TabAvatarImageRenderer.render(photo: photo, isSelected: false)
            self.selectedIcon = TabAvatarImageRenderer.render(photo: photo, isSelected: true)
        }
    }
}
