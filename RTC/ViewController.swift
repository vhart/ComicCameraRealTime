//
//  ViewController.swift
//  RTC
//
//  Created by Varindra Hart on 5/3/19.
//  Copyright © 2019 VH. All rights reserved.
//

import UIKit
import AVFoundation
import GPUImage

class GPUImageViewController: UIViewController {
    lazy var backImageView: UIImageView = {
        let v = UIImageView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.image = UIImage(named: "city")
        return v
    }()

    lazy var iv: GPUImageView = {
        let v = GPUImageView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .clear
        return v
    }()

    var videoCamera: GPUImageVideoCamera!
    let customFilter = GPUImageChromaKeyFilter()

    override func viewDidLoad() {
//        view.backgroundColor = .blue

        view.addSubview(backImageView)
        NSLayoutConstraint.activate([
            backImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])

        view.addSubview(iv)
        NSLayoutConstraint.activate([
            iv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            iv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            iv.topAnchor.constraint(equalTo: view.topAnchor),
            iv.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])

        videoCamera = GPUImageVideoCamera(sessionPreset: AVCaptureSession.Preset.photo.rawValue, cameraPosition: .back)
        videoCamera.outputImageOrientation = .portrait;

        // Add the view somewhere so it's visible

//        let renderer = UIGraphicsImageRenderer(bounds: CGRect(x: 0, y: 0, width: 1, height: 1))
//        let image = renderer.image { (context) in
//            UIColor.red.setFill()
//            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
//        }
//        let red = GPUImagePicture(image: image)
//
        videoCamera.addTarget(customFilter)
//        red?.addTarget(customFilter)
        customFilter.addTarget(iv)
        customFilter.thresholdSensitivity = 0.7
        

        videoCamera.startCapture()
    }
}


class ViewController: UIViewController {

    let captureSession = CaptureSession()
    var setCount = 0

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    lazy var captureButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .red
        button.addTarget(self, action: #selector(capture(button:)), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession.avSession)
        view.layer.addSublayer(previewLayer)
        captureSession.onImageCaptured = { [weak self] image in
            DispatchQueue.main.async {
                self?.update(withImage: image)
            }
        }

        layoutImageView()
        layoutCaptureButton()
        captureSession.initialize()
    }

    private func layoutImageView() {
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            ])
    }

    private func layoutCaptureButton() {
        view.addSubview(captureButton)
        captureButton.layer.cornerRadius = 30
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40),
            captureButton.widthAnchor.constraint(equalToConstant: 60),
            captureButton.heightAnchor.constraint(equalToConstant: 60)
            ])
    }

    @objc private func capture(button: UIButton) {
        defer {
            button.backgroundColor = .red
            button.isEnabled = true
        }

        button.backgroundColor = .gray
        button.isEnabled = false

        if let image = imageView.image {
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
        }
    }

    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer){
        if let error = error{
            let ac = UIAlertController(title: "Error while saving", message: error.localizedDescription, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "Ok", style: .default))
            present(ac, animated: true)
        } else {
            let ac = UIAlertController(title: "Success!", message: "The Image has been saved successfully", preferredStyle: .alert)
//            ac.addAction(UIAlertAction(title: "Ok", style: .default))
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                ac.dismiss(animated: true, completion: nil)
            }
            present(ac, animated: true)
        }
    }

    func update(withImage image: UIImage) {
//        guard setCount < 5 else { return }

        imageView.image = image
        setCount += 1
    }

}

class CaptureSession: NSObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {

    var avSession = AVCaptureSession()

    private let chromaFilter = ChromaKey()

    private var backCamera: AVCaptureDevice?
    private var frontCamera: AVCaptureDevice?
    private var currentCamera: AVCaptureDevice?
    private var videoOrientation: AVCaptureVideoOrientation

    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let photoSessionPreset = AVCaptureSession.Preset.photo

    private let sessionQueue = DispatchQueue(label: "session Queue")

    var onImageCaptured: ((UIImage) -> Void)?

    override init() {
        let statusBarOrientation = UIApplication.shared.statusBarOrientation
        if statusBarOrientation != .unknown,
            let videoOrientation = AVCaptureVideoOrientation(rawValue: statusBarOrientation.rawValue) {
            self.videoOrientation = videoOrientation
        } else {
            self.videoOrientation = .portrait
        }
    }

    private func setupCaptureSession() {
        setupPhotoCaptureSession()
        setupDevices()
        setUpCaptureSessionInput(position: .back)
    }

    func captureImage(){
        takePhoto()
    }

    func initialize() {
        setupCaptureSession()
        configureOutput()
        startRunningCaptureSession()
    }

    // This function sets up a switch to change the camera in use depending on current position when called.
    private func setUpCaptureSessionInput(position: AVCaptureDevice.Position) {
        switch position {
        case .back:
            currentCamera = backCamera
        case .front:
            currentCamera = frontCamera
        default:
            currentCamera = backCamera
        }

        setupInputOutput()
    }

    //This function will be called when the VC sets up the capture session so that the output connection is set before the first photo is taken so that it doesn't come out black.
    func configureOutput() {
        self.photoOutput?.connection(with: .video)?.videoOrientation = self.videoOrientation
        self.photoOutput?.isHighResolutionCaptureEnabled = true
        self.videoOutput?.connection(with: .video)?.videoOrientation = self.videoOrientation
    }

    // Mark:- @objc functions for buttons
    // This is the function that will be called when the take photo button is pressed.
    @objc func takePhoto() {
        sessionQueue.async {
            self.photoOutput?.connection(with: .video)?.videoOrientation = self.videoOrientation
            let settings = AVCapturePhotoSettings()
            settings.isHighResolutionPhotoEnabled = true
            self.photoOutput?.capturePhoto(with: settings, delegate: self)
        }
    }

    // This function switches the camera.
    @objc func switchCamera() {
        guard let currentPosition = currentCamera?.position else { return }
        let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        setUpCaptureSessionInput(position: newPosition)
    }

    func updateOrientation(orientation: AVCaptureVideoOrientation) {
        videoOrientation = orientation
    }

    // AVCapturePhotoCaptureDelegate methods. This extension is used because you need to wait until the photo you took "didFinishProcessing" before you can handle the image.
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation() {

            guard let image = UIImage(data: imageData) else { return }

            onImageCaptured?(image)
        }
    }

    // Mark:- AVCapture Session Setup functions
    // This function sets up the photo capture session as well as the photo ouput instance and its settings.
    private func setupPhotoCaptureSession(){
        avSession.beginConfiguration()
        avSession.sessionPreset = photoSessionPreset
        avSession.commitConfiguration()

        //        photoOutput = AVCapturePhotoOutput()
        //        photoOutput?.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])], completionHandler: nil)
        //        avSession.addOutput(photoOutput!)
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.alwaysDiscardsLateVideoFrames = true
        videoOutput?.setSampleBufferDelegate(self, queue: sessionQueue)
        avSession.addOutput(videoOutput!)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let cameraImage = CIImage(cvPixelBuffer: pixelBuffer!)

//        let comicEffect = CIFilter(name: "CIComicEffect")!
//
//        comicEffect.setValue(cameraImage, forKey: kCIInputImageKey)

        let greenScreened = chromaFilter.filterAndComposite(foregroundCIImage: cameraImage)

        let context = CIContext() // Prepare for create CGImage
        let cgimg = context.createCGImage(greenScreened!, from: greenScreened!.extent)

        let filteredImage = UIImage(cgImage: cgimg!)
        onImageCaptured?(filteredImage)
    }

    // This function allows you to have the application discover the devices camera(s)
    private func setupDevices(){
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
        let devices = deviceDiscoverySession.devices

        for device in devices {
            if device.position == AVCaptureDevice.Position.back {
                backCamera = device
            } else if device.position == AVCaptureDevice.Position.front {
                frontCamera = device
            }
        }
    }

    // This function allows you to remove the current camera input in use and to set and enable a new camera input.
    private func setupInputOutput(){
        avSession.beginConfiguration()
        if let currentInput = avSession.inputs.first {
            avSession.removeInput(currentInput)
        }
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: currentCamera!)
            avSession.addInput(captureDeviceInput)
        } catch {
            print(error)
        }
        avSession.commitConfiguration()
    }

    // This function creates a layer in the view that will enable a live feed of what your camera is observing.
    //    private func setupPreviewLayer(view: AVCapturePreviewView){
    //        view.avPreviewLayer.session = avSession
    //        view.avPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
    //        view.avPreviewLayer.connection?.videoOrientation = videoOrientation
    //    }

    // Starts running the capture session after you set up the view.
    private func startRunningCaptureSession(){
        avSession.startRunning()
    }
}
