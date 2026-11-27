//
//  DamnlinesFixture.swift
//  locTests
//
//  Snapshot of https://damnlines.com/data/line-index (CC BY 4.0, damnlines.com) for parsing tests.
//

enum DamnlinesFixture {
    static let indexJSON = #"""
{
  "dataset": "damnlines NYC Line Index",
  "description": "Measured average and peak wait times (minutes) and typical line sizes at line-famous New York City restaurants, aggregated by day and hour from per-minute camera counts of each venue's actual line.",
  "methodology": "https://damnlines.com/average-wait-times",
  "license": "CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)",
  "attribution": "damnlines (damnlines.com). When citing, link the venue page or damnlines.com/average-wait-times.",
  "timezone": "America/New_York",
  "venue_count": 9,
  "venues": [
    {
      "venue": "Caffè Panna",
      "neighborhood": "Gramercy",
      "city": "New York, NY",
      "page": "https://damnlines.com/camera/caffe-panna",
      "average_wait_minutes": 18,
      "peak": {
        "wait_minutes": 27,
        "day": "Friday",
        "hour_local": "8 PM",
        "typical_line_size": 22
      },
      "shortest_wait": {
        "wait_minutes": 7,
        "day": "Tuesday",
        "hour_local": "1 PM"
      },
      "history_days": 181
    },
    {
      "venue": "L'industrie Pizzeria",
      "neighborhood": "West Village",
      "city": "New York, NY",
      "page": "https://damnlines.com/camera/lindustrie-pizzeria",
      "average_wait_minutes": 17,
      "peak": {
        "wait_minutes": 26,
        "day": "Saturday",
        "hour_local": "5 PM",
        "typical_line_size": 29
      },
      "shortest_wait": {
        "wait_minutes": 8,
        "day": "Monday",
        "hour_local": "9 PM"
      },
      "history_days": 242
    },
    {
      "venue": "Salt Hank's",
      "neighborhood": "West Village",
      "city": "New York, NY",
      "page": "https://damnlines.com/camera/salt-hanks",
      "average_wait_minutes": 16,
      "peak": {
        "wait_minutes": 35,
        "day": "Saturday",
        "hour_local": "1 PM",
        "typical_line_size": 21
      },
      "shortest_wait": {
        "wait_minutes": 5,
        "day": "Thursday",
        "hour_local": "2 PM"
      },
      "history_days": 166
    },
    {
      "venue": "Bánh Anh Em",
      "neighborhood": "East Village",
      "city": "New York, NY",
      "page": "https://damnlines.com/camera/banh-anh-em",
      "average_wait_minutes": 15,
      "peak": {
        "wait_minutes": 23,
        "day": "Saturday",
        "hour_local": "1 PM",
        "typical_line_size": 18
      },
      "shortest_wait": {
        "wait_minutes": 5,
        "day": "Sunday",
        "hour_local": "9 PM"
      },
      "history_days": 219
    },
    {
      "venue": "Breakfast by Salt's Cure",
      "neighborhood": "West Village",
      "city": "New York, NY",
      "page": "https://damnlines.com/camera/breakfast-by-salts-cure",
      "average_wait_minutes": 12,
      "peak": {
        "wait_minutes": 46,
        "day": "Saturday",
        "hour_local": "12 PM",
        "typical_line_size": 27
      },
      "shortest_wait": {
        "wait_minutes": 0,
        "day": "Tuesday",
        "hour_local": "2 PM"
      },
      "history_days": 168
    },
    {
      "venue": "Lucinda's",
      "neighborhood": "East Village",
      "city": "New York, NY",
      "page": "https://damnlines.com/camera/lucindas",
      "average_wait_minutes": 8,
      "peak": {
        "wait_minutes": 28,
        "day": "Friday",
        "hour_local": "11 PM",
        "typical_line_size": 22
      },
      "shortest_wait": {
        "wait_minutes": 0,
        "day": "Friday",
        "hour_local": "3 AM"
      },
      "history_days": 211
    },
    {
      "venue": "The Halal Guys",
      "neighborhood": "Midtown",
      "city": "New York, NY",
      "page": "https://damnlines.com/camera/the-halal-guys",
      "average_wait_minutes": 6,
      "peak": {
        "wait_minutes": 10,
        "day": "Saturday",
        "hour_local": "10 PM",
        "typical_line_size": 16
      },
      "shortest_wait": {
        "wait_minutes": 0,
        "day": "Friday",
        "hour_local": "4 AM"
      },
      "history_days": 208
    },
    {
      "venue": "Golden Diner",
      "neighborhood": "Two Bridges",
      "city": "New York, NY",
      "page": "https://damnlines.com/camera/golden-diner",
      "average_wait_minutes": 5,
      "peak": {
        "wait_minutes": 13,
        "day": "Saturday",
        "hour_local": "9 AM",
        "typical_line_size": 10
      },
      "shortest_wait": {
        "wait_minutes": 1,
        "day": "Tuesday",
        "hour_local": "5 PM"
      },
      "history_days": 175
    },
    {
      "venue": "John's of Bleecker Street",
      "neighborhood": "West Village",
      "city": "New York, NY",
      "page": "https://damnlines.com/camera/johns-of-bleecker-street",
      "average_wait_minutes": 1,
      "peak": {
        "wait_minutes": 3,
        "day": "Saturday",
        "hour_local": "2 PM",
        "typical_line_size": 5
      },
      "shortest_wait": {
        "wait_minutes": 0,
        "day": "Tuesday",
        "hour_local": "11 AM"
      },
      "history_days": 240
    }
  ]
}
"""#
}
