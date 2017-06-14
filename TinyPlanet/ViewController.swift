//
//  ViewController.swift
//  TinyPlanetMac
//
//  Created by Leo Thomas on 17.05.17.
//  Copyright © 2017 Leonard Thomas. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    var filter: VideoFilter?
    
    @IBOutlet weak var progressbar: NSProgressIndicator!
    @IBOutlet weak var loadButton: NSButton!
    @IBOutlet weak var saveButton: NSButton!
    @IBOutlet weak var previewLabel: NSTextField!
    @IBOutlet weak var previewImageView: NSImageView!
    @IBOutlet weak var previewButton: NSButton!
    @IBOutlet weak var typeSegmentControl: NSSegmentedControl!
    
    var showLivePreview = false
    var previewTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        saveButton.isEnabled = false
        previewButton.isEnabled = false
        typeSegmentControl.isEnabled = false
        previewLabel.stringValue = "press open to select a file"
        previewImageView.imageScaling = .scaleProportionallyDown
        resetTimer()
    }

    @IBAction func modeChanged(_ sender: NSSegmentedControl) {
        filter?.type = FilterType(rawValue: sender.selectedSegment)
        requestPreviewImage()
    }
    
    @IBAction func loadButtonClicked(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["mp4"]
        
        if panel.runModal() == NSFileHandlingPanelOKButton,
            let url = panel.url {
            filter = VideoFilter(url: url)
            filter?.onWrongImageRatio = showWrongImageRatioAlert
            filter?.newImageHandler = updatePreview
            previewLabel.stringValue = url.path
            saveButton.isEnabled = true
            previewButton.isEnabled = true
            typeSegmentControl.isEnabled = true
            requestPreviewImage()
        }
    }
    
    func requestPreviewImage() {
        previewImageView.image = nil
        filter?.player.play()
        resetTimer()
        previewTimer?.fire()
    }
    
    func update(timer: Timer) {
        self.filter?.updateFrame(time: self.filter!.player.currentTime())
        if self.previewImageView.image != nil && !showLivePreview {
            timer.invalidate()
            filter?.player.pause()
        }
    }
    
    func updatePreview(image: NSImage) {
        previewImageView.image = image
    }
    
    func resetTimer() {
        previewTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: update)
    }
    
    @IBAction func chagePreviewMode(_ sender: NSButton) {
        showLivePreview = !showLivePreview
        if showLivePreview {
            resetTimer()
            previewTimer?.fire()
            filter?.player.play()
            sender.title = "Disable preview"
        } else {
            previewTimer?.invalidate()
            filter?.player.pause()
            sender.title = "Enable preview"
        }
    }
       
    @IBAction func saveClicked(_ sender: Any) {
        
        if let type = filter?.type,
            type == .none {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Please select a transformation mode before rendering the video"
            alert.runModal()
            return
        }
        
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["mp4"]
        if panel.runModal() == NSFileHandlingPanelOKButton,
            let url = panel.url {
            progressbar.isHidden = false
            progressbar.doubleValue = 0
            progressbar.maxValue = 1
            saveButton.isEnabled = false
            filter?.render(to: url, progess: { (progess) in
                self.progressbar.doubleValue = Double(progess)
            }, completion: { success in
                saveButton.isEnabled = true
                self.progressbar.doubleValue = 0
                NSWorkspace.shared().open(url)
            })
        }
    }
    
    func showWrongImageRatioAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "The current version only the transformation of videos with an ratio of 2:1. Cut the video in another application to get better results"
        alert.runModal()
    }
    
}
