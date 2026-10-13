import CoreLocation
import MapKit
import UIKit

/// Hands stops off to the Apple Maps or Google Maps app for turn-by-turn navigation.
enum MapsLauncher {
    /// What to open: directions through a whole day, or a single place.
    enum Target {
        case day([StopSnapshot])
        case place(StopSnapshot)
    }

    /// Opens the target in the given app.
    /// `.askEachTime` isn't an app, so callers resolve it (by asking the user) before calling this.
    static func open(_ target: Target, in app: MapApp) {
        switch (app, target) {
        case (.appleMaps, .day(let stops)): openDayInAppleMaps(stops)
        case (.appleMaps, .place(let stop)): openPlaceInAppleMaps(stop)
        case (.googleMaps, .day(let stops)): openDayInGoogleMaps(stops)
        case (.googleMaps, .place(let stop)): openPlaceInGoogleMaps(stop)
        case (.askEachTime, _):
            assertionFailure("Resolve .askEachTime to a specific app before opening")
        }
    }

    // MARK: Apple Maps

    /// Opens Apple Maps with directions through every stop, in order.
    static func openDayInAppleMaps(_ stops: [StopSnapshot]) {
        guard !stops.isEmpty else { return }
        // With the directions option, Maps treats the items as a route from the first to the last.
        MKMapItem.openMaps(
            with: stops.map(mapItem(for:)),
            launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault]
        )
    }

    /// Opens Apple Maps showing a single place.
    static func openPlaceInAppleMaps(_ stop: StopSnapshot) {
        mapItem(for: stop).openInMaps()
    }

    private static func mapItem(for stop: StopSnapshot) -> MKMapItem {
        let location = CLLocation(latitude: stop.coordinate.latitude, longitude: stop.coordinate.longitude)
        let item = MKMapItem(location: location, address: nil)
        // Without a name Maps would label the pin with raw coordinates.
        item.name = stop.name
        return item
    }

    // MARK: Google Maps

    /// Opens Google Maps with directions through every stop, in order.
    static func openDayInGoogleMaps(_ stops: [StopSnapshot]) {
        guard let first = stops.first, let last = stops.last else { return }
        guard stops.count > 1 else {
            openPlaceInGoogleMaps(first)
            return
        }

        // The app's URL scheme chains waypoints onto the destination with "+to:".
        let destinations = stops.dropFirst().map(coordinateText).joined(separator: "+to:")
        let appURL = URL(string: "comgooglemaps://?saddr=\(coordinateText(first))&daddr=\(destinations)")

        // The web URL uses origin/destination plus a "|"-separated waypoint list for the stops in between.
        var web = URLComponents(string: "https://www.google.com/maps/dir/")
        web?.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "origin", value: coordinateText(first)),
            URLQueryItem(name: "destination", value: coordinateText(last)),
        ]
        let middle = stops.dropFirst().dropLast()
        if !middle.isEmpty {
            web?.queryItems?.append(URLQueryItem(name: "waypoints", value: middle.map(coordinateText).joined(separator: "|")))
        }

        open(appURL: appURL, webURL: web?.url)
    }

    /// Opens Google Maps showing a single place.
    static func openPlaceInGoogleMaps(_ stop: StopSnapshot) {
        let coordinate = coordinateText(stop)
        let appURL = URL(string: "comgooglemaps://?q=\(coordinate)&center=\(coordinate)")

        var web = URLComponents(string: "https://www.google.com/maps/search/")
        web?.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: coordinate),
        ]
        open(appURL: appURL, webURL: web?.url)
    }

    /// Opens the Google Maps app if it's installed, otherwise the same directions on the web.
    /// `canOpenURL` only works for `comgooglemaps` because it's listed in LSApplicationQueriesSchemes.
    private static func open(appURL: URL?, webURL: URL?) {
        if let appURL, UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL {
            UIApplication.shared.open(webURL)
        }
    }

    /// "lat,lon", the format both Google URLs expect.
    private static func coordinateText(_ stop: StopSnapshot) -> String {
        "\(stop.coordinate.latitude),\(stop.coordinate.longitude)"
    }
}
