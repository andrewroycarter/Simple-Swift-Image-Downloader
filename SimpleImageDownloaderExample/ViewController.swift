//
//  ViewController.swift
//  SimpleImageDownloaderExample
//
//  Created by Andrew Carter on 10/1/17.
//  Copyright © 2017 Andrew Carter. All rights reserved.
//

import UIKit

final class ViewController: UIViewController {

    @IBOutlet var imageView: UIImageView!
    private let imageURL = URL(string: "https://upload.wikimedia.org/wikipedia/en/a/a9/Example.jpg")!
    private let imageGetter = ImageGetter()

    @IBAction func getImageButtonPressed() {
        imageGetter.getImage(from: imageURL) { [weak self] result in
            guard let strongSelf = self else {
                return
            }

            DispatchQueue.main.async {
                switch result {
                case .ok(let image):
                    strongSelf.imageView.image = image

                case .error(let error):
                    print("Failed to get image: \(error)")
                    strongSelf.imageView.image = nil
                }
            }
        }
    }

}

