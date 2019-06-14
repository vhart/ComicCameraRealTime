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
    let city = UIImage(named: "city")
    let raptors = UIImage(named: "raptorsstuff")
    lazy var backImageView: UIImageView = {
        let v = UIImageView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.image = raptors
        return v
    }()

    lazy var iv: GPUImageView = {
        let v = GPUImageView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .clear
        return v
    }()

    lazy var slider: UISlider = {
        let s = UISlider()
        s.maximumValue = 1.0
        s.minimumValue = 0.0
        s.translatesAutoresizingMaskIntoConstraints = false
        s.addTarget(self, action: #selector(slide(sender:)), for: .valueChanged)

        return s
    }()

    lazy var replaceSq: GPUImagePicture = {
        let renderer = UIGraphicsImageRenderer(bounds: CGRect(x: 0, y: 0, width: 1, height: 1))
        let image = renderer.image { (context) in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return GPUImagePicture(image: image)
    }()

    lazy var replaceSq2: GPUImagePicture = {
        let renderer = UIGraphicsImageRenderer(bounds: CGRect(x: 0, y: 0, width: 1, height: 1))
        let image = renderer.image { (context) in
            UIColor.clear.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return GPUImagePicture(image: image)
    }()

    @objc func slide(sender: UISlider) {
        customFilter.thresholdSensitivity = CGFloat(sender.value)
    }

    var videoCamera: GPUImageVideoCamera!
    let customFilterGreenChromaOnly = GPUImageChromaKeyFilter()
    let customFilter = GPUImageChromaKeyBlendFilter()
    let clearFilter = GPUImageChromaKeyBlendFilter()
    let filterGroup = GPUImageFilterGroup()

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

        view.addSubview(slider)
        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            slider.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            slider.heightAnchor.constraint(equalToConstant: 30)
            ])


        videoCamera = GPUImageVideoCamera(sessionPreset: AVCaptureSession.Preset.photo.rawValue, cameraPosition: .back)
        videoCamera.outputImageOrientation = .portrait;

        let tap = UITapGestureRecognizer(target: self, action: #selector(capture))
        view.addGestureRecognizer(tap)

        // Add the view somewhere so it's visible


        //
        //        let r = UIColor.red.cgColor.components!.map{ Float($0) }
        //        customFilter.setColorToReplaceRed(r[0], green: r[1], blue: r[2])
//        customFilter.thresholdSensitivity = 0.3
        videoCamera.addTarget(customFilter)
        replaceSq.addTarget(customFilter)

//        clearFilter.thresholdSensitivity = 0.3
        customFilter.addTarget(clearFilter)
        replaceSq2.addTarget(clearFilter)

        replaceSq.processImage()
        replaceSq2.processImage()

        clearFilter.addTarget(iv)

        //        filterGroup.initialFilters = [customFilter]
        //        filterGroup.terminalFilter = clearFilter

        videoCamera.startCapture()
    }

    @objc func didTap() {
        //        customFilter.useNextFrameForImageCapture()
        //        let img = customFilter.imageFromCurrentFramebuffer()
        //        if let averageColor = img?.averageColor {
        //            let v = UIView(frame: CGRect(origin: view.center,
        //                                         size: CGSize(width: 100, height: 100))
        //            )
        //            v.backgroundColor = averageColor
        //            view.addSubview(v)
        //
        //            DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: {
        //                v.removeFromSuperview()
        //
        //                if let comps = averageColor.cgColor
        //                    .components?
        //                    .map({ Float($0) * 255}) {
        //                    self.customFilter.setColorToReplaceRed(comps[0], green: comps[1], blue: comps[2])
        //                }
        //
        //            })
        //        }

    }

    @objc private func capture() {
        customFilter.useNextFrameForImageCapture()
        let img = customFilter.imageFromCurrentFramebuffer()
        let scaledImg = scaledImage(city!, for: img!.size)
        print(img)
        print("------")
        print(scaledImg)

        DispatchQueue.global().async {

            let newChroma = GPUImageChromaKeyBlendFilter()
            let s1 = GPUImagePicture(image: img!)
            let s2 = GPUImagePicture(image: scaledImg!)
            s1!.addTarget(newChroma)
            s2!.addTarget(newChroma)

            newChroma.useNextFrameForImageCapture()
            s1?.processImage()
            s2?.processImage()
            let blend = newChroma.imageFromCurrentFramebuffer()


            if let d = scaledImg {
                DispatchQueue.main.async {
                    UIImageWriteToSavedPhotosAlbum(d, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
                }
            } else {
                print("FAILED TO BLEND")
            }
        }
    }

    func scaledImage(_ base: UIImage, for size: CGSize) -> UIImage? {
        let scale = max(size.height/base.size.height, size.width/base.size.width)
        let scaledSize = base.size.applying(scale: scale)
        let origin = CGPoint(x: (scaledSize.width - size.width) / -2,
                             y: (scaledSize.height - size.height) / -2)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            base.draw(in: CGRect(origin: origin, size: size))
        }
        return image
//        guard let cgimg = image.cgImage?
//            .cropping(to: CGRect(origin: , size: size))
//            else { return nil }
//
//        return UIImage(cgImage: cgimg)
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
}

extension CGSize {
    func applying(scale: CGFloat) -> CGSize {
        return CGSize(width: self.width * scale, height: self.height * scale)
    }
}

extension UIImage {
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: CGFloat(bitmap[3]) / 255)
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
