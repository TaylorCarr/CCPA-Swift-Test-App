//
//  ContentView.swift
//  Firebase Swift
//
//  Created by T Carr on 1/10/20.
//  Copyright © 2020 T Carr. All rights reserved.
//

import SwiftUI
import Firebase
import MapKit
import CoreLocation
import AdSupport
import ACPCore
import ACPAnalytics
import Adjust
import GoogleMobileAds
import WebKit

let settings = UserDefaults.standard
let encoder: JSONEncoder = JSONEncoder()

struct payload: Codable {
    var appDetails: [String: String]?
    var userDetails: [String: String?]
    var alternateIds: [[String: String?]?]
}


struct ContentView: View {
    @State var DNS = settings.bool(forKey: "donnotSell")
    @ObservedObject var DNSToggle = DNSDelegate()
    @State var showModal = false
    
    let package = payload(appDetails: ["appAssetId": "WBGAME000001031", "appName" : "DC Legends", "additionalInfo" : "Build Version:1.26.2;AppPlatform:iOS;"], userDetails: ["firstName": nil, "lastName" : nil, "email" : "", "region" : nil], alternateIds: [["idType" : "profile_id", "id" : "c28d9a8f7e13c9af6a5ec58a", "context" : ""]])
        //payload(accessKey: "vVZidbBIpOpfO80HjF0MC6pEGIMOhz", requestType: "DO_NOT_SELL", appDetails: ["appAssetId": "WBGAME000001031", "appName" : "DC Legends", "additionalInfo" : "Build Version:1.26.2;AppPlatform:ANDROID;"], userDetails: ["firstName": nil, "lastName" : nil, "email" : "", "region" : nil], alternateIds: [["idType" : "profile_id", "id" : "c28d9a8f7e13c9af6a5ec58a", "context" : ""]])
        //
    
    let stringURL = "https://dev.privacycenter.wb.com/index.php/wp-json/appdata/"
    // "https://privacycenter.wb.com/index.php/wp-json/appdata/"
    
    var body: some View {
        ZStack {
            VStack {
                GADBannerViewController().frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 0.1, alignment: .top)
                VStack {
                    Toggle(isOn: self.$DNSToggle.DNS.toggle) {
                        Text("Do Not Sell")
                    }.padding()
                    Button(action: {
                            self.showModal.toggle()
                        }) {
                            Text(verbatim: "Privacy Center")
                        }.sheet(isPresented: $showModal, content: {
                            webView(url: self.stringURL, request: self.prepRequest(stringURL: self.stringURL))
                            }
                        )
                }.frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 0.8, alignment: .center)
                
            }
        }
    }
    
    
    func prepRequest(stringURL: String) -> URLRequest {
        var req = URLRequest(url: URL(string: stringURL)!)
        
        req.httpMethod = "POST"
        req.httpBody = try! encoder.encode(package)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer vVZidbBIpOpfO80HjF0MC6pEGIMOhz", forHTTPHeaderField: "Authorization") // dev - Authorization
        //req.setValue("Bearer rnUXeHa4MwCbgouARZTp8N9wz5YZ2m", forHTTPHeaderField: "Authorization") // prod
        req.setValue("DO_NOT_SELL", forHTTPHeaderField: "requestType")
        print("Header: \(req.allHTTPHeaderFields!)")
        print("Body: \(String(data: req.httpBody!, encoding: .utf8)!)")
        return req
    }
}

struct webView: UIViewRepresentable {
    
    typealias UIViewType = WKWebView
    var url: String
    let request: URLRequest
    
    func makeUIView(context: UIViewRepresentableContext<webView>) -> WKWebView {
        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.allowsInlineMediaPlayback = true
    
        let wkwebview = WKWebView(frame: .zero, configuration: webViewConfiguration)
        wkwebview.autoresizingMask = .flexibleWidth
        wkwebview.autoresizingMask = .flexibleHeight
        
        return wkwebview
    }
    
    func updateUIView(_ uiView: WKWebView, context: UIViewRepresentableContext<webView>) {
        uiView.load(request)
    }
}



class DNSDelegate: ObservableObject {
    @Published var DNS: ListSection = ListSection()
}

struct ListSection {
    var MAID: String?
    var toggle: Bool = false {
        didSet {
            if (toggle == false) {
                settings.set(false, forKey: "donotSell")
                settings.set(false, forKey: "gad_rdp")
                Analytics.setAnalyticsCollectionEnabled(false)
            }
            else {
                settings.set(true, forKey: "donotSell")
                settings.set(true, forKey: "gad_rdp")
                Analytics.setAnalyticsCollectionEnabled(true)
            }
            
            logPrivacyDNSCurrentState()
    }
}
    
    func logPrivacyDNSCurrentState() {
        let IDFV = UIDevice.current.identifierForVendor!.uuidString
        let appName: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        let appVersion: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let platform = "iOS"
        let DNSStatus = (UserDefaults.standard.bool(forKey: "donotSell") ? "1":"0")
        
        if (UserDefaults.standard.object(forKey: "donotSell") != nil) {
            // Google Analytics
            Analytics.logEvent("DNS_CurrentState", parameters: ["IDFV":IDFV, "DNSStatus":DNSStatus, "appName":appName!, "appVersion":appVersion!, "platform":platform])
              
            // Adobe Analytics
            ACPCore.trackAction("DNS_CurrentState", data: ["IDFV":IDFV, "DNSStatus": DNSStatus, "appName":appName!, "appVersion":appVersion!, "platform":platform ])
            
            // Adjust
            let DNS_CurrentState = ADJEvent(eventToken: "DNS_CurrentState")
            DNS_CurrentState?.addCallbackParameter("IDFV", value: IDFV)
            DNS_CurrentState?.addCallbackParameter("DNSStatus", value: DNSStatus)
            DNS_CurrentState?.addCallbackParameter("appName", value: appName!)
            DNS_CurrentState?.addCallbackParameter("appVersion", value: appVersion!)
            DNS_CurrentState?.addCallbackParameter("platform", value: platform)
            Adjust.trackEvent(DNS_CurrentState);
        }
    }

func DNSToggled(enabled: Bool) {
    let defaults = UserDefaults.standard

    if defaults.object(forKey: "privacyAnalyticsCollected") == nil {
        logPrivacyDNSCurrentState()
        defaults.set(true, forKey: "privacyAnalyticsCollected")
    }
    
    var MAID: String = ""
    if (ASIdentifierManager.shared().isAdvertisingTrackingEnabled) {
        MAID = ASIdentifierManager.shared().advertisingIdentifier.uuidString
    }
    
    if (enabled == false) {
        Analytics.logEvent("DNS_Disabled", parameters: ["MAID": MAID])
    }
    else if (enabled == true) {
       Analytics.logEvent("DNS_Enabled", parameters: ["MAID":MAID])
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
}


final class GADBannerViewController: UIViewControllerRepresentable  {

    func makeUIViewController(context: Context) -> UIViewController {
        let view = GADBannerView(adSize: kGADAdSizeBanner)
        let viewController = UIViewController()
        //view.adUnitID = "ca-app-pub-3940256099942544/2934735713"
        //view.adUnitID = "ca-app-pub-7888296544691661/3536449740"
        view.adUnitID = "ca-app-pub-3940256099942544/2934735716" // test ad id
        view.rootViewController = viewController
        view.delegate = viewController
        viewController.view.addSubview(view)
        viewController.view.frame = CGRect(origin: .zero, size: kGADAdSizeBanner.size)
        view.load(GADRequest())
        return viewController
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

extension UIViewController: GADBannerViewDelegate {
    public func adViewDidReceiveAd(_ bannerView: GADBannerView) {
        print("ok ad")
    }

    public func adView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: GADRequestError) {
       print("fail ad")
       print(error)
    }
}
