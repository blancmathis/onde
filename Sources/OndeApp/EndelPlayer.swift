import AppKit
import SwiftUI
import WebKit
import OndeCore

/// Uses only YouTube's documented IFrame Player API. No extraction, proxy,
/// download, advertising filter, or access to Endel/YouTube credentials.
/// https://developers.google.com/youtube/iframe_api_reference
/// https://developers.google.com/youtube/terms/required-minimum-functionality
final class EndelPlayer: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate, NSWindowDelegate {
    @Published private(set) var selected: EndelSession?
    @Published private(set) var state = "idle"
    @Published private(set) var error: String?
    @Published private(set) var duration: Double = 0
    @Published private(set) var position: Double = 0
    private var web: WKWebView?
    private var window: NSWindow?
    private var ready = false
    private var wantsPlay = false
    private var volume = 0.35
    private var generation = 0
    var onState: ((String) -> Void)?

    func load(_ session: EndelSession, volume: Double) {
        generation += 1
        let ticket = generation
        selected = session; self.volume = volume; duration = 0; position = 0
        error = nil; state = "loading"; ready = false; wantsPlay = true
        if window == nil {
            let config = WKWebViewConfiguration()
            config.mediaTypesRequiringUserActionForPlayback = []
            config.userContentController.add(self, name: "ondeEndel")
            // Separate web storage owned by Onde; existing browser cookies are never read.
            let view = WKWebView(frame: .zero, configuration: config)
            view.navigationDelegate = self
            web = view
            let host = NSWindow(contentRect: NSRect(x: 160, y: 130, width: 880, height: 590), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            host.isReleasedWhenClosed = false; host.delegate = self
            host.minSize = NSSize(width: 680, height: 490)
            host.contentView = NSHostingView(rootView: EndelPlayerWindow(player: self, web: view))
            window = host
        }
        window?.title = "Onde · Endel — \(session.title)"
        show()
        // The app bundle ID is the referrer, as required by YouTube for macOS.
        let origin = "https://" + (Bundle.main.bundleIdentifier ?? "app.onde.mac").lowercased()
        let html = """
        <!doctype html><html lang="fr"><head><meta name="referrer" content="strict-origin-when-cross-origin"><meta name="viewport" content="width=device-width,initial-scale=1"><style>html,body{margin:0;background:#171d1a;width:100%;height:100%;}#player{width:100%;height:100%;}</style></head><body><div id="player"></div><script>
        const ticket=\(ticket); let player=null, wanted=true, gain=\(volume * 100);
        function report(data){data.ticket=ticket;window.webkit.messageHandlers.ondeEndel.postMessage(data);}
        function ondeControl(command,value){if(command==='pause')wanted=false;if(command==='play')wanted=true;if(command==='volume')gain=value;if(!player||typeof player.getPlayerState!=='function')return;
          if(command==='play')player.playVideo();if(command==='pause')player.pauseVideo();if(command==='stop'){wanted=false;player.stopVideo();}if(command==='volume')player.setVolume(value);if(command==='seek')player.seekTo(value,true);}
        window.onYouTubeIframeAPIReady=function(){player=new YT.Player('player',{videoId:'\(session.videoID)',host:'https://www.youtube-nocookie.com',playerVars:{autoplay:0,controls:1,playsinline:1,origin:'\(origin)'},events:{
          onReady:function(){player.setVolume(gain);report({event:'ready'});if(wanted)player.playVideo();},
          onStateChange:function(e){report({event:'state',state:e.data,duration:player.getDuration(),position:player.getCurrentTime()});},
          onError:function(e){report({event:'error',code:e.data});},
          onAutoplayBlocked:function(){report({event:'blocked'});}}});};
        setInterval(function(){if(player&&typeof player.getDuration==='function')report({event:'progress',duration:player.getDuration(),position:player.getCurrentTime()});},1000);
        </script><script src="https://www.youtube.com/iframe_api" onerror="report({event:'network_error'})"></script></body></html>
        """
        web?.loadHTMLString(html, baseURL: URL(string: origin + "/"))
        DispatchQueue.main.asyncAfter(deadline: .now() + 18) { [weak self] in
            guard let self, self.generation == ticket, !self.ready else { return }
            self.setError("YouTube n’a pas répondu. Vérifiez la connexion ou utilisez Ouvrir dans le navigateur. Aucune lecture n’est confirmée.")
        }
    }
    func show() { window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    func play() { guard selected != nil else { return }; wantsPlay = true; show(); control("play") }
    func pause() { wantsPlay = false; control("pause") }
    func setVolume(_ value: Double) { volume = value; control("volume", value: value * 100) }
    func seek(_ value: Double) throws {
        guard ready, duration > 0 else { throw OndeError("player_not_ready", "La lecture Endel n’est pas prête.") }
        guard value.isFinite, value >= 0, value < duration else { throw OndeError("invalid_argument", "La position doit être comprise dans la durée du morceau.") }
        control("seek", value: value)
    }
    private func control(_ command: String, value: Double? = nil) {
        let args: [Any] = [command, value as Any? ?? NSNull()]
        guard let bytes = try? jsonData(args), let json = String(data: bytes, encoding: .utf8) else { return }
        web?.evaluateJavaScript("if(typeof ondeControl==='function'){ondeControl.apply(null,\(json));}", completionHandler: nil)
    }
    func clear() {
        generation += 1; wantsPlay = false; selected = nil; ready = false
        state = "idle"; error = nil; duration = 0; position = 0
        web?.loadHTMLString("<html><body style='background:#171d1a'></body></html>", baseURL: nil)
        window?.orderOut(nil)
    }
    func setError(_ message: String) { error = message; state = "error"; onState?("error") }
    func windowShouldClose(_ sender: NSWindow) -> Bool { pause(); onState?("paused"); sender.orderOut(nil); return false }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { setError(error.localizedDescription) }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let o = message.body as? [String:Any], let ticket = o["ticket"] as? Int, ticket == generation, let event = o["event"] as? String else { return }
        if let n = o["duration"] as? Double, n.isFinite, n >= 0 { duration = n }
        if let n = o["position"] as? Double, n.isFinite, n >= 0 { position = n }
        switch event {
        case "ready": ready = true; state = "ready"; error = nil; if !wantsPlay { pause() }
        case "state":
            let value = o["state"] as? Int ?? -1
            state = [0:"ended",1:"playing",2:"paused",3:"buffering",5:"ready"][value] ?? "ready"
            if value == 1 { error = nil }; onState?(state)
        case "blocked": state = "needs_click"; error = "Cliquez sur Lecture dans le lecteur YouTube pour démarrer."; onState?(state)
        case "error": setError("YouTube signale l’erreur \(o["code"] ?? "inconnue"). Le fournisseur peut limiter la lecture intégrée ; essayez le navigateur.")
        case "network_error": setError("Connexion à YouTube impossible. Aucune lecture complète n’est confirmée.")
        default: break
        }
    }
    func snapshot() -> [String:Any] {
        var result: [String:Any] = ["source":"official_youtube", "state":state]
        if let selected { result["session"] = selected.descriptor } else { result["session"] = NSNull() }
        result["duration_seconds"] = duration
        result["position_seconds"] = position
        if let error { result["error"] = error } else { result["error"] = NSNull() }
        result["ready"] = ready
        result["offline"] = false
        result["playback_confirmed"] = state == "playing"
        return result
    }
}
struct EndelWebView: NSViewRepresentable {
    let view: WKWebView
    func makeNSView(context: Context) -> WKWebView { view }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
struct EndelPlayerWindow: View {
    @ObservedObject var player: EndelPlayer
    let web: WKWebView
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Endel · \(player.selected?.title ?? "Session complète")").font(.system(size: 22, design: .serif))
                    Text("Publication intégrale · lecteur officiel YouTube · connexion requise").font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
                Spacer()
                if let s = player.selected { Link("Ouvrir dans le navigateur", destination: URL(string:s.url)!).font(.system(size:11)).tint(Theme.accent) }
            }
            // Provider controls remain fully visible, never hidden behind an overlay.
            EndelWebView(view:web).frame(minWidth: 480, minHeight: 270).frame(maxWidth:.infinity,maxHeight:.infinity)
            if let error = player.error { Text(error).font(.system(size:11)).foregroundStyle(.orange).fixedSize(horizontal:false,vertical:true) }
            HStack {
                Text(player.state).font(.system(size:11,design:.monospaced)).foregroundStyle(Theme.muted)
                Spacer()
                Text("\(clockText(player.position)) / \(player.duration > 0 ? clockText(player.duration) : "durée à vérifier")").font(.system(size:11,design:.monospaced))
                Button("Pause") { player.pause() }.buttonStyle(.bordered)
                Button("Lecture") { player.play() }.buttonStyle(.bordered)
            }
            Text("Pas de téléchargement audio ni de suppression des publicités. Fermer ce lecteur met la lecture en pause.").font(.system(size:10)).foregroundStyle(Theme.muted)
        }.padding(22).background(Theme.sidebar).foregroundStyle(Theme.ink).preferredColorScheme(.dark)
    }
}
struct EndelSessionsView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        PageHeader(eyebrow:"Endel · versions intégrales",title:"Des sessions entières. Pas des extraits.",subtitle:"Publications officielles de 1 à 8 heures. Lecture en ligne, distincte de votre bibliothèque hors ligne.")
        Panel {
            VStack(alignment:.leading,spacing:12) {
                Text("Le vrai son, dans son lecteur officiel.").font(.system(size:22,design:.serif))
                Text("Lancer une session ouvre le lecteur YouTube complet. Le chrono démarre à la confirmation de lecture ; les sons locaux sont suspendus, sans modifier vos mélanges. Une connexion et, selon YouTube, un clic ou une connexion au compte peuvent être nécessaires.").font(.system(size:12)).foregroundStyle(Theme.muted).lineSpacing(4)
                Text("Ces enregistrements ne sont pas le moteur adaptatif personnalisé d’Endel. Les durées affichées sont celles annoncées par l’éditeur, arrondies.").font(.system(size:11)).foregroundStyle(Theme.muted)
                HStack {
                    Link("Ouvrir Endel avec mon compte",destination:URL(string:"https://play.endel.io/")!).tint(Theme.accent)
                    Spacer()
                    Button("État du lecteur") { model.notify("Endel : " + model.endel.state); model.endel.show() }
                }.font(.system(size:11))
            }
        }
        ForEach(EndelSession.all) { session in
            Panel {
                HStack(spacing:16) {
                    Image(systemName:session.mode.symbol).font(.system(size:24,weight:.light)).foregroundStyle(Theme.accent(session.mode)).frame(width:35)
                    VStack(alignment:.leading,spacing:6) {
                        Text(session.title).font(.system(size:19,design:.serif))
                        Text("Endel · chaîne officielle · \(session.minutes >= 120 ? "\(session.minutes / 60) heures" : "\(session.minutes) minutes")").font(.system(size:11)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    if session.mode == .relax {
                        Button("Avec méditation") { model.startEndel(session.id, meditation:true) }.font(.system(size:11)).buttonStyle(.plain).foregroundStyle(Theme.accent(.meditation))
                    }
                    PillButton(title:"Lire la session",symbol:"play.fill",primary:true) { model.startEndel(session.id) }
                }
            }
        }
        Text("Méditation : carillons à 10, 20 et 30 minutes par défaut, puis aucun. Le chrono continue même à la fin de la vidéo. Les publicités et restrictions du fournisseur restent applicables.").font(.system(size:11)).foregroundStyle(Theme.muted).lineSpacing(4)
    }
}
