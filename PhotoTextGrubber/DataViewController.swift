//
//  DataViewController.swift
//  PhotoTextGrubber
//
//  Created by Codedigger on 2017/02/06.
//  Copyright © 2017 Codedigger. All rights reserved.
//

import UIKit
import MobileCoreServices
//On the top of your swift
extension UIImage {
    func getPixelColor(pos: CGPoint) -> CGColor {
        let pixelData = self.cgImage!.dataProvider!.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        var r:CGFloat = CGFloat(0.0)
        var g:CGFloat = CGFloat(0.0)
        var b:CGFloat = CGFloat(0.0)
        var a:CGFloat = CGFloat(0.0)
        let bytesPerRow = Int((self.cgImage?.bytesPerRow)!) / 4
        for i in stride(from: 0, through: Int(self.scale - 1), by: 1){
            for j in stride(from: 0, through: Int(self.scale - 1), by: 1){
                let pixelInfo: Int = (bytesPerRow * (Int(pos.y * self.scale)  + i) + Int(pos.x * self.scale) + j) * 4
                b += (CGFloat(data[pixelInfo]) / CGFloat(255.0))
                g += (CGFloat(data[pixelInfo+1]) / CGFloat(255.0))
                r += (CGFloat(data[pixelInfo+2]) / CGFloat(255.0))
                a += (CGFloat(data[pixelInfo+3]) / CGFloat(255.0))
            }
        }
        let tmp:CGFloat = self.scale * self.scale
        b = b / tmp
        g = g / tmp
        r = r / tmp
        a = a / tmp
/*
        print(CGFloat(data[pixelInfo]) )
        print(CGFloat(data[pixelInfo+1]) )
        print(CGFloat(data[pixelInfo+2]) )
        print(CGFloat(data[pixelInfo+3]) )
        print(CGFloat(data[pixelInfo+4]) )
        print(CGFloat(data[pixelInfo+5]) )
        print(CGFloat(data[pixelInfo+6]) )
        print(CGFloat(data[pixelInfo+7]) )
 */
        return UIColor(red: r, green: g, blue: b, alpha: a).cgColor
    }
}

class DataViewController:  UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate,UIScrollViewDelegate {
    @IBOutlet weak var scrollView: UIScrollView!
    var dataObject: String = ""
    var imageView = UIImageView()
    var cropedView = UIImageView()
    var tempCanvasView = UIImageView()
    var resultView = UIImageView()
    var newMedia: Bool?
    var maxScale:CGFloat = 4.0
    var lastPoint = CGPoint.zero
    var red: CGFloat = 0.0
    var green: CGFloat = 1.0
    var blue: CGFloat = 0.0
    var brushWidth: CGFloat = 10.0
    var opacity: CGFloat = 1.0
    var swiped = false
    var maxImageSize:CGFloat = 4000000.0
    var canvasImageBuff = UIImage()
    var viewImageBuff = UIImage()
    var tempExtractArea = CGRect(x:0,y:0,width:0,height:0)
    var extractAreaList = [CGRect]()
    var drawingHistory = [[CGPoint]]()
    var drawingCach = [CGPoint]()
    let resultImageTop:CGFloat = 30.0
    let resultImageLeft:CGFloat = 10.0
    @IBOutlet weak var useGallaryBtn: UIButton!
    @IBOutlet weak var capBtn: UIButton!
    @IBOutlet weak var cropBtn: UIButton!
    @IBOutlet weak var bcakBtn: UIButton!
    @IBOutlet weak var freezeBtn: UIButton!
    @IBOutlet weak var resume: UIButton!
    @IBOutlet weak var cancleBtn: UIButton!
    @IBOutlet weak var confirmBtn: UIButton!
    
    @IBAction func back(_ sender: Any) {
        self.freezeBtn.isHidden = true
        self.capBtn.isHidden = false
        self.useGallaryBtn.isHidden = false
        self.cropBtn.isHidden = true
        self.freezeBtn.isHidden = true
        self.resume.isHidden = true
        self.confirmBtn.isHidden = true
        self.cancleBtn.isHidden = true
        self.unloadImage()
        self.scrollView.isDirectionalLockEnabled =  true
        self.scrollView.isScrollEnabled =  true
        self.scrollView.isUserInteractionEnabled =  true
        self.clearDrawhistory()
    }
    
    @IBAction func resume(_ sender: Any) {
        self.scrollView.isScrollEnabled = true
        self.scrollView.isDirectionalLockEnabled =  true
        self.scrollView.isUserInteractionEnabled = true
        self.resume.isHidden = true
        self.freezeBtn.isHidden = false
    }
    func buildBlock(in inPoint:CGPoint ) -> CGRect{
        let halfbrushwidth = self.brushWidth / 2
        let x = min(max(inPoint.x - halfbrushwidth, 0), self.tempCanvasView.frame.maxX - 1)
        let y = min(max(inPoint.y - halfbrushwidth, 0), self.tempCanvasView.frame.maxY - 1)
        let width = min(self.tempCanvasView.frame.maxX - inPoint.x, brushWidth)
        let height = min(self.tempCanvasView.frame.maxY - inPoint.y, brushWidth)
        return CGRect(x:x, y: y, width:width,height:height)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        swiped = false
        if let touch = touches.first {
            lastPoint = touch.location(in: self.view)
            if(drawingCach.count > 0){
                drawingCach.removeAll()
            }
            //lastPoint = self.offsetPoint(lastPoint)
            drawingCach.append(lastPoint)
            self.tempExtractArea = self.buildBlock(in: self.offsetPoint(lastPoint))
        }
    }
    
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        swiped = true
        if let touch = touches.first {
            if view.traitCollection.forceTouchCapability == .available {
                //if touch.force == touch.maximumPossibleForce {
                let currentPoint = touch.location(in: view)
                drawLineFrom(from: lastPoint, to: currentPoint)
                lastPoint = currentPoint
            }

        }
    }
    
    func offsetPoint(_ inPoint: CGPoint) -> CGPoint{
        let pointOffset = CGPoint(x: self.scrollView.contentOffset.x - self.tempCanvasView.frame.origin.x, y: self.scrollView.contentOffset.y - self.tempCanvasView.frame.origin.y)
        let x = max(inPoint.x + pointOffset.x, 0)
        let y = max(inPoint.y + pointOffset.y, 0)
        return CGPoint(x:Int(x), y:Int(y))
    }
    
    func drawLineFrom(from in_fromPoint: CGPoint, to in_toPoint: CGPoint){
        let fromPoint = self.offsetPoint(in_fromPoint)
        let toPoint =  self.offsetPoint(in_toPoint)
        drawingCach.append(toPoint)
        self.tempExtractArea = self.tempExtractArea.union(self.buildBlock(in: toPoint))
        //let fromPoint = in_fromPoint
        //let toPoint = in_toPoint
        //print(self.tempCanvasView.bounds)
        //let drawArea = CGRect(x: self.scrollView.contentOffset.x,y: self.scrollView.contentOffset.y,width: self.view.bounds.size.width,height: self.view.bounds.size.height)
        UIGraphicsBeginImageContextWithOptions(self.tempCanvasView.bounds.size, false, 0)
        self.tempCanvasView.image?.draw(in: self.tempCanvasView.bounds)
        let context = UIGraphicsGetCurrentContext()
        context?.move(to: fromPoint)
        context?.addLine(to: toPoint)
        context?.setLineCap(CGLineCap.round)
        context?.setLineWidth(brushWidth)
        context?.setStrokeColor(red: red, green: green, blue: blue, alpha:opacity)
        //context?.setBlendMode(CGBlendMode.normal)
        context?.strokePath()
        self.tempCanvasView.image = UIGraphicsGetImageFromCurrentImageContext()
        self.tempCanvasView.alpha = opacity
        UIGraphicsEndImageContext()
    }
    
    func clearDrawhistory() {
        self.drawingHistory.removeAll()
        self.extractAreaList.removeAll()
        self.tempExtractArea =  CGRect(x:0,y:0,width:0,height:0)

    }
    
    @IBAction func cropCancle(_ sender: Any) {
        self.imageView.image = self.viewImageBuff
        self.tempCanvasView.image = self.canvasImageBuff
        self.cropBtn.isHidden = true
        self.confirmBtn.isHidden = true
        self.cancleBtn.isHidden = true
        self.resume.isHidden = false
        self.cropedView.image = nil
        self.scrollView.isUserInteractionEnabled = false
    }
    
    @IBAction func cropConfirm(_ sender: Any) {
        if(self.extractAreaList.isEmpty){
            return
        }
        var hight = self.extractAreaList[0].size.height
        var tmp = 0
        var maxHeight = hight
        for area in self.extractAreaList{
            tmp += Int(area.width)
            if(tmp > Int(view.frame.size.width)){
                tmp = Int(area.width)
                hight += maxHeight
            }
            if(area.height > maxHeight){
                maxHeight = area.height
            }
        }
        self.resultView.frame = CGRect(x: self.resultImageLeft, y: self.resultImageTop, width: view.frame.width, height: hight)
        UIGraphicsBeginImageContext(CGSize(width: view.frame.width, height: hight))
        self.resultView.image?.draw(in: CGRect(x: 0, y: 0, width: view.frame.width, height: hight))
        var start_posx = 0
        var start_posy = 0
        maxHeight = 0
        let context = UIGraphicsGetCurrentContext()
        for area in self.extractAreaList{
            start_posx += Int(area.width)
            if(start_posx > Int(view.frame.size.width)){
                start_posx = 0
                start_posy += Int(maxHeight)
                maxHeight = 0
            }
            if(area.height > maxHeight){
                maxHeight = area.height
            }
            for x in Int(area.minX)...Int(area.maxX - 1){
                for y in Int(area.minY)...Int(area.maxY - 1){
                    let pos = CGPoint(x: x,y: y )
                    let pos1 = CGPoint(x: x - Int(area.minX) + start_posx,y: y - Int(area.minY) + start_posy )
                    let color = self.cropedView.image?.getPixelColor(pos: pos)
                    context?.move(to: pos1)
                    context?.addLine(to: pos1)
                    context?.setLineCap(CGLineCap.round)
                    context?.setLineWidth(1)
                    context?.setStrokeColor(color!)
                    context?.setBlendMode(CGBlendMode.normal)
                    context?.strokePath()
                }
            }
            start_posx += Int(area.size.width)
        }
        self.resultView.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.scrollView.frame = self.cropedView.frame
        self.scrollView.bounds = self.cropedView.frame
        self.cropedView.image = nil


    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        if !swiped {
            // draw a single pointå
            drawLineFrom(from : lastPoint, to : lastPoint)
        }
        drawingHistory.append([CGPoint](drawingCach))
        // Merge tempImageView into mainImageView
        UIGraphicsBeginImageContext(self.tempCanvasView.bounds.size)
        //self.canvasView.image?.draw(in:self.canvasView.bounds, blendMode: CGBlendMode.normal, alpha: opacity)
        self.tempCanvasView.image?.draw(in: self.tempCanvasView.bounds, blendMode: CGBlendMode.normal, alpha: opacity)
        //self.canvasView.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.cropBtn.isHidden = false
        if(self.extractAreaList.isEmpty){
            self.extractAreaList.append(self.tempExtractArea)
            return
        }
        for i in 0...self.extractAreaList.count - 1{
            if(extractAreaList[i].intersects(self.tempExtractArea)){
                extractAreaList[i].union(self.tempExtractArea)
                return
            }
            if(self.tempExtractArea.minY < extractAreaList[i].minY || (self.tempExtractArea.minY == extractAreaList[i].minY && self.tempExtractArea.minX < extractAreaList[i].minX) ){
                self.extractAreaList.insert(self.tempExtractArea , at: i)
                return
            }
        }
        self.extractAreaList.append(self.tempExtractArea)
        //self.tempCanvasView.image = nil
    }
    
    @IBAction func UseGallary(_ sender: Any) {

        if UIImagePickerController.isSourceTypeAvailable(
            UIImagePickerControllerSourceType.savedPhotosAlbum) {
            let imagePicker = UIImagePickerController()
            
            imagePicker.delegate = self
            imagePicker.sourceType =
                UIImagePickerControllerSourceType.photoLibrary
            imagePicker.mediaTypes = [kUTTypeImage as String]
            imagePicker.allowsEditing = false
            self.present(imagePicker, animated: true,
                         completion: nil)
            newMedia = false
            self.freezeBtn.isHidden = false
            self.capBtn.isHidden = true
            self.useGallaryBtn.isHidden = true
        }
    }
    
    @IBAction func CapPicture(_ sender: Any) {
        print("Cap")
        if UIImagePickerController.isSourceTypeAvailable(
            UIImagePickerControllerSourceType.camera) {
            
            let imagePicker = UIImagePickerController()
            
            imagePicker.delegate = self
            imagePicker.sourceType =
                UIImagePickerControllerSourceType.camera
            imagePicker.mediaTypes = [kUTTypeImage as String]
            imagePicker.allowsEditing = false
            print("Yes Cap")
            self.present(imagePicker, animated: true,
                         completion: nil)
            newMedia = true
            self.freezeBtn.isHidden = false
            self.capBtn.isHidden = true
            self.useGallaryBtn.isHidden = true
        }else{
            print("No Cap")

        }
    }
    
    func setImageByDeviceSize(inImageView:UIImageView) -> UIImageView{
        inImageView.bounds = CGRect(x: 0, y: 0, width: view.bounds.size.width, height:view.bounds.size.height)
        inImageView.frame = self.imageView.bounds
        return inImageView
    }
    
    func imageViewinit(){
        self.scrollView.delegate = self
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.flashScrollIndicators()
        self.scrollView.frame = self.view.bounds
        self.scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.scrollView.maximumZoomScale = self.maxScale
        self.automaticallyAdjustsScrollViewInsets = false
        self.imageView = self.setImageByDeviceSize(inImageView: self.imageView)
        self.tempCanvasView = self.setImageByDeviceSize(inImageView: self.tempCanvasView)
        self.scrollView.addSubview(imageView)
        self.scrollView.addSubview(self.tempCanvasView)
        self.scrollView.addSubview(self.cropedView)
        self.scrollView.addSubview(self.resultView)
        print("imageViewinit")
        
    }
    
    @IBAction func Freeze(_ sender: Any) {
        /*
        self.freezeFlag = !self.freezeFlag
        if(self.freezeFlag){
            self.imageOffset = scrollView.contentOffset
            scrollView.contentSize = self.view.bounds.size
            scrollView.contentOffset = self.imageOffset
            scrollView.bounces = false
            self.maxScale = scrollView.maximumZoomScale
            self.minScale = scrollView.minimumZoomScale
            scrollView.maximumZoomScale = scrollView.zoomScale;
            scrollView.minimumZoomScale = scrollView.zoomScale;
        }else{
            scrollView.bounces = true
            self.scrollView.contentSize = self.scrollSize!
            scrollView.maximumZoomScale = maxScale;
            scrollView.minimumZoomScale = minScale;
          }
         */
        self.scrollView.isScrollEnabled = false
        self.scrollView.isDirectionalLockEnabled =  false
        self.scrollView.isUserInteractionEnabled = false
        self.resume.isHidden = false
        self.freezeBtn.isHidden = true
       
    }
    
    func resizeImage(image: UIImage, scale: CGFloat) -> UIImage {
        let newWidth = image.size.width * scale
        let newHeight = image.size.height * scale
        UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
        image.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }

    func setZoomScale() {
        let imageViewSize = imageView.bounds.size
        let viewSize = self.view.bounds.size
        let widthScale = viewSize.width / imageViewSize.width
        let heightScale = viewSize.height / imageViewSize.height
        self.scrollView.minimumZoomScale = min(widthScale, heightScale,1.0)
        let xpos = max((viewSize.width - imageViewSize.width * self.scrollView.zoomScale ) / 2, 0)
        let ypos = max((viewSize.height - imageViewSize.height * self.scrollView.zoomScale) / 2, 0)
        self.imageView.frame = CGRect(x: xpos, y: ypos, width: imageViewSize.width, height:imageViewSize.height)
        print(self.imageView.frame)
        self.cropedView.frame = CGRect(x: xpos, y: ypos, width: imageViewSize.width, height:imageViewSize.height)
        self.tempCanvasView.frame = CGRect(x: xpos, y: ypos, width: imageViewSize.width, height:imageViewSize.height)
        //self.scrollView.zoomScale = self.scrollView.minimumZoomScale
        self.scrollView.zoomScale = 1.0
        //self.scrollView.zoomScale = self.scrollView.minimumZoomScale
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()        // Do any additional setup after loading the view, typically from a nib.
        self.imageViewinit()
        self.cropBtn.isHidden = true
        self.freezeBtn.isHidden = true
        self.confirmBtn.isHidden = true
        self.resume.isHidden = true
        self.cancleBtn.isHidden = true
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView?
    {
        return imageView
    }
    
    override func viewWillLayoutSubviews() {
        setZoomScale()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    
    @IBAction func crop(_ sender: Any) {
        if(self.extractAreaList.isEmpty){
            return
        }
        print(self.extractAreaList)
        print(self.tempCanvasView.frame)
        //print(self.tempCanvasView.image?.size)
        UIGraphicsBeginImageContextWithOptions(self.tempCanvasView.bounds.size, false, 0)
        self.cropedView.image?.draw(in: self.tempCanvasView.bounds)
        let context = UIGraphicsGetCurrentContext()
        for area in self.extractAreaList{
            for x in Int(area.minX)...Int(area.maxX - 1){
                for y in Int(area.minY)...Int(area.maxY - 1){
                    //let pos = offsetPoint(CGPoint(x: x,y: y ))
                    let pos = CGPoint(x: x,y: y )
                    //var c = self.tempCanvasView.image?.getPixelColor(pos:pos)
                    if((self.tempCanvasView.image?.getPixelColor(pos:pos))!.alpha > 0){
                        let color = self.imageView.image?.getPixelColor(pos: pos)
                        context?.move(to: pos)
                        context?.addLine(to: pos)
                        context?.setLineCap(CGLineCap.round)
                        context?.setLineWidth(1)
                        //context?.setStrokeColor(color!)
                        context?.setStrokeColor(color!)
                        context?.setBlendMode(CGBlendMode.normal)
                        context?.strokePath()
                    }
                }
            }
            
        }
        self.cropedView.image = UIGraphicsGetImageFromCurrentImageContext()
        self.cropedView.alpha = 1
        UIGraphicsEndImageContext()
        self.cropBtn.isHidden = true
        self.freezeBtn.isHidden = true
        self.resume.isHidden = true
        self.canvasImageBuff = self.tempCanvasView.image!
        self.viewImageBuff = self.imageView.image!
        self.tempCanvasView.image = nil
        self.imageView.image = nil
        self.confirmBtn.isHidden = false
        self.cancleBtn.isHidden = false
        self.scrollView.isUserInteractionEnabled = true
        self.scrollView.isScrollEnabled = true

    }
    
    func unloadImage(){
        self.scrollView.zoomScale = 1.0
        self.imageView.image = nil
        self.tempCanvasView.image = nil
        self.cropedView.image = nil
        self.imageView.bounds = view.bounds
        self.scrollView.contentSize = imageView.bounds.size
        self.tempCanvasView.bounds = self.imageView.bounds
        self.cropedView.bounds = self.imageView.bounds
        print(self.imageView.bounds)
        self.setZoomScale()
        
    }
    
    func loadImage(inImage:UIImage){
        self.scrollView.zoomScale = 1.0
        var tmpImage = inImage
        let imageSize = inImage.size.width *  inImage.size.height
        if(imageSize > self.maxImageSize){
            tmpImage = self.resizeImage(image: inImage, scale: maxImageSize / imageSize)
        }
        self.imageView.image = tmpImage
        self.imageView.bounds = CGRect(x: 0, y: 0, width: tmpImage.size.width, height:tmpImage.size.height)
        self.scrollView.contentSize = imageView.bounds.size
        self.tempCanvasView.bounds = self.imageView.bounds
        self.cropedView.bounds = self.imageView.bounds
        print(self.imageView.bounds)
        self.setZoomScale()
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let mediaType = info[UIImagePickerControllerMediaType] as! NSString
        self.dismiss(animated: true, completion: nil)
        
        if mediaType.isEqual(to: kUTTypeImage as String) {
            let image = info[UIImagePickerControllerOriginalImage]
                as! UIImage
            self.loadImage(inImage:image)
            if (newMedia == true) {
                UIImageWriteToSavedPhotosAlbum(image, self,
                                            #selector(DataViewController.image(image:didFinishSavingWithError:contextInfo:)), nil)
            } else if mediaType.isEqual(to: kUTTypeMovie as String) {
                // Code to support video here
            }
            
        }
    }
    
    func image(image: UIImage, didFinishSavingWithError error: NSErrorPointer, contextInfo:UnsafeRawPointer) {
        
        if error != nil {
            let alert = UIAlertController(title: "Save Failed",
                                          message: "Failed to save image",
                                          preferredStyle: UIAlertControllerStyle.alert)
            
            let cancelAction = UIAlertAction(title: "OK",
                                             style: .cancel, handler: nil)
            
            alert.addAction(cancelAction)
            self.present(alert, animated: true,
                         completion: nil)
        }
    }

}

