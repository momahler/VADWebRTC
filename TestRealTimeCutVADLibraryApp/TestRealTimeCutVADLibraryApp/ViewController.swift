//
//  ViewController.swift
//  TestRealTimeCutVADLibraryApp
//
//  Created by Yasushi Sakita on 2025/02/04.
//

import UIKit
import AVFoundation
import RealTimeCutVADLibrary

enum RECORDING_STATUS {
    case TALKING
    case RUNNING
    case OFF
}

class ViewController: UIViewController {

    private var vadManager : VADWrapper?
    
    private var audioPlayer : AudioPlayer?
    private var audioEngine: AVAudioEngine? = nil
    private var desiredFormat: AVAudioFormat? = nil
        
    @IBOutlet weak var micTypeLbl: UILabel!
    @IBOutlet weak var micImg: UIImageView!
    @IBOutlet weak var btns: UIStackView!
    
    private var collectedPCMData = Data()
    private let pcmDataQueue = DispatchQueue(label: "com.example.pcmDataQueue")
    
    private var speechVoiceAudio: Data? = nil {
        didSet {
            if speechVoiceAudio != nil {
                DispatchQueue.main.async {
                    self.btns.isHidden = false
                }
            }
        }
    }
    
    private var recordingStatus: RECORDING_STATUS = .OFF {
        didSet {
            switch recordingStatus {
            case .TALKING:
                DispatchQueue.main.async {
                    self.micImg.tintColor = .red
                }
            case .RUNNING:
                DispatchQueue.main.async {
                    self.micImg.tintColor = .green
                }
            case .OFF:
                DispatchQueue.main.async {
                    self.micImg.tintColor = .black
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        audioPlayer = AudioPlayer()
        audioPlayer?.delegate = self
        
        setupRecording()
        startRecording()
        recordingStatus = .RUNNING
        
        if let micName = getCurrentMicName() {
            micTypeLbl.text = micName
        } else {
            micTypeLbl.text = "Unknown Mic"
        }
    }
}


extension ViewController: VADDelegate {
    
    func voiceStarted() {
        print("voiceStarted")
        recordingStatus = .TALKING
        
        // Initialize (clear) previously collected PCM data
        self.collectedPCMData = Data()
    }
    
    func voiceEnded(withWavData wavData: Data!) {
        print("voiceEnded")
        recordingStatus = .RUNNING
        speechVoiceAudio = wavData
    }
    
    func voiceDidContinue(withPCMFloat pcmFloatData: Data!) {
        print("voiceDidContinue")
        
        // ⚠️ Process RealTimeCut VAD on a separate thread to avoid blocking the main thread.
        pcmDataQueue.async { [weak self] in
            guard let self = self, let data = pcmFloatData else { return }

            // Append (concatenate) the new PCM data to the private variable.
            self.collectedPCMData.append(data)
        }
    }
}

extension ViewController {
    
    func setupRecording() {
        
        audioEngine = AVAudioEngine()
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                        
            vadManager = nil
            vadManager = VADWrapper()
            vadManager?.delegate = self
            vadManager?.setSileroModel(.v5)
            
            let sampleRate = audioSession.sampleRate
            switch sampleRate {
            case 48000.0:
                vadManager?.setSamplerate(.SAMPLERATE_48)
            case 24000.0:
                vadManager?.setSamplerate(.SAMPLERATE_24)
            case 16000.0:
                vadManager?.setSamplerate(.SAMPLERATE_16)
            case 8000.0:
                vadManager?.setSamplerate(.SAMPLERATE_8)
            default:
                vadManager = nil
                showModal(title: "error", description: "not support samplerate")
                return;
            }
            
            desiredFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: true)
            
        } catch {
            showModal(title: "error", description: "setupRecording\n\(error)")
        }
    }
    
    func startRecording() {
        
        guard let desiredFormat = desiredFormat, let vadManager = vadManager, let audioEngine = audioEngine else {
            return
        }
        
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 4800, format: desiredFormat) { (buffer, time) in
            
            guard let channelData = buffer.floatChannelData else {
                return
            }
            let frameLength = UInt(buffer.frameLength)
            let monoralData = channelData[0]
            vadManager.processAudioData(withBuffer: monoralData, count: frameLength)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch  {
            showModal(title: "error", description: "startRecording\n\(error)")
        }
    }
    
    func stopRecording() {
        
        guard let audioEngine = audioEngine else {
            return
        }
        
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
    }
    
    func teardownRecording() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            showModal(title: "error", description: "teardownRecording\n\(error)")
        }
    }
}

extension ViewController: AudioPlayerDelegate {
    
    func playStart() {
        recordingStatus = .OFF
        stopRecording()
    }
    
    func playEnd() {
        startRecording()
        recordingStatus = .RUNNING
    }
}

extension ViewController {
    
    @IBAction func playClicked(_ sender: Any) {
        guard let data = speechVoiceAudio else { return }
        audioPlayer?.play(data: data)
    }
    
    @IBAction func shareClicked(_ sender: Any) {
        
        guard let data = speechVoiceAudio else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        let timestamp = dateFormatter.string(from: Date())
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(timestamp).wav")
        let tempPCMDataURL = FileManager.default.temporaryDirectory.appendingPathComponent("VoiceDidContinueAppend_16khz_32bit_\(timestamp).pcm")
            
        do {
            try data.write(to: tempURL)
            try collectedPCMData.write(to: tempPCMDataURL)
            
            let activityVC = UIActivityViewController(activityItems: [tempURL, tempPCMDataURL], applicationActivities: nil)
            if let popoverController = activityVC.popoverPresentationController {
                popoverController.sourceView = self.view
                popoverController.sourceRect = CGRect(x: self.view.bounds.midX,
                                                      y: self.view.bounds.midY,
                                                      width: 0,
                                                      height: 0)
                popoverController.permittedArrowDirections = []
            }
            
            self.present(activityVC, animated: true, completion: nil)
            
        } catch {
            showModal(title: "error", description: "shareClicked\n\(error)")
        }
    }
}

protocol AudioPlayerDelegate {
    func playStart()
    func playEnd()
}
class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    
    var player: AVAudioPlayer?
    var delegate: AudioPlayerDelegate?
    
    func play(data: Data) {
        do {
            player = try AVAudioPlayer(data: data)
            player?.delegate = self
            player?.prepareToPlay()
            delegate?.playStart()
            player?.play()
        } catch {
            print("Initialization failed: AVAudioPlayer: \(error)")
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        delegate?.playEnd()
    }
}

extension ViewController {
    
    func getCurrentMicName() -> String? {
        let audioSession = AVAudioSession.sharedInstance()
        var currentInputPortName: String? = nil
        if let currentInput = audioSession.preferredInput {
            currentInputPortName = currentInput.portName
        } else if let currentInput = audioSession.currentRoute.inputs.first {
            currentInputPortName = currentInput.portName
        }
        return currentInputPortName
    }
    
    func showModal(title: String, description: String) {
        let alertController = UIAlertController(title: title, message: description, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }
}
