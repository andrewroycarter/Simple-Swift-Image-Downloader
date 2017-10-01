//
//  Result.swift
//  SimpleImageDownloaderExample
//
//  Created by Andrew Carter on 10/1/17.
//  Copyright © 2017 Andrew Carter. All rights reserved.
//

import Foundation

enum Result<T> {
    case ok(T)
    case error(Error)
}
