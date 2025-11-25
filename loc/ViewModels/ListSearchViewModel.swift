//
//  ListSearchViewModel.swift
//  loc
//
//  Created by Cursor on 11/20/25.
//  ViewModel responsible for searching place lists with pagination
//

import Foundation
import Combine

@MainActor
class ListSearchViewModel: ObservableObject {
    // MARK: - Published State
    @Published var searchResults: [LightweightPlaceList] = []
    @Published var isSearching: Bool = false
    @Published var searchText: String = ""
    @Published var hasMoreResults: Bool = false
    @Published var isLoadingMore: Bool = false
    
    // MARK: - Dependencies
    private let userService: SupabaseUserService
    private let userSession: UserSession
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Pagination
    private var currentPage: Int = 1
    private let pageSize: Int = 20
    
    // MARK: - Init
    init(userService: SupabaseUserService = .shared,
         userSession: UserSession) {
        self.userService = userService
        self.userSession = userSession
        setupSearchDebouncing()
    }
    
    // MARK: - Setup
    
    /// Debounce search input (300ms delay) - prevents excessive API calls
    private func setupSearchDebouncing() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                Task {
                    await self?.performSearch(query: searchText)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public API
    
    /// Perform search with debouncing
    private func performSearch(query: String) async {
        // Cancel previous search to prevent race conditions
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            clearSearch()
            return
        }
        
        guard let userId = userSession.currentUserId else {
            clearSearch()
            return
        }
        
        isSearching = true
        currentPage = 1
        searchResults = []
        
        searchTask = Task {
            do {
                let results = try await userService.searchPlaceLists(
                    userId: userId,
                    query: query,
                    page: currentPage,
                    pageSize: pageSize
                )
                
                guard !Task.isCancelled else { return }
                
                searchResults = results
                hasMoreResults = results.count >= pageSize
                isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                searchResults = []
                hasMoreResults = false
                isSearching = false
            }
        }
    }
    
    /// Load more search results (pagination)
    func loadMoreResults() async {
        guard !isLoadingMore,
              hasMoreResults,
              !searchText.isEmpty,
              let userId = userSession.currentUserId else {
            return
        }
        
        isLoadingMore = true
        let nextPage = currentPage + 1
        
        do {
            let moreResults = try await userService.searchPlaceLists(
                userId: userId,
                query: searchText,
                page: nextPage,
                pageSize: pageSize
            )
            
            if !moreResults.isEmpty {
                searchResults.append(contentsOf: moreResults)
                currentPage = nextPage
                hasMoreResults = moreResults.count >= pageSize
            } else {
                hasMoreResults = false
            }
        } catch {
            // Keep hasMoreResults true to allow retry
        }
        
        isLoadingMore = false
    }
    
    /// Check if should load more based on current index
    func shouldLoadMore(currentIndex: Int) -> Bool {
        guard hasMoreResults, !isLoadingMore else { return false }
        // Load when within 3 items of the end
        return currentIndex >= searchResults.count - 3
    }
    
    /// Clear search state
    func clearSearch() {
        searchTask?.cancel()
        searchResults = []
        hasMoreResults = false
        isSearching = false
        currentPage = 1
    }
}

