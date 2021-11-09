//
//  ViewController.swift
//  MoyaTest
//
//  Created by 홍서진 on 2021/11/09.
//

import UIKit
import Moya
import Alamofire
import RxSwift

enum ForumService {
    case getPosts
    case deletePost(id: Int)
}

// https://medium.com/@mattiacontin/better-networking-with-moya-rxswift-a90d821f1ce8

extension ForumService: TargetType {
    
    
    // This is the base URL we'll be using, typically our server.
    var baseURL: URL {
    return URL(string: "https://jsonplaceholder.typicode.com")!
    }

    // This is the path of each operation that will be appended to our base URL.
    var path: String {
        switch self {
        case .getPosts:
            return "/posts"
        case .deletePost(let id):
            return "/posts/\(id)"
        }
    }

    // Here we specify which method our calls should use.
    var method: Moya.Method {
        switch self {
        case .getPosts:
            return .get
        case .deletePost:
            return .delete
        }
    }
    
    
    // Here we specify body parameters, objects, files etc.
    // or just do a plain request without a body.
    // In this example we will not pass anything in the body of the request.
    var task: Task {
        return .requestPlain
    }

    // These are the headers that our service requires.
    // Usually you would pass auth tokens here.
    var headers: [String: String]? {
        return ["Content-type": "application/json"]
    }

    // This is sample return data that you can use to mock and test your services,
    // but we won't be covering this.
    var sampleData: Data {
        return Data()
    }
}

struct ForumNetworkManager {

    // I'm using a singleton for the sake of demonstration and other lies I tell myself
    static let shared = ForumNetworkManager()
    
    // This is the provider for the service we defined earlier
    private let provider = MoyaProvider<ForumService>(plugins: [NetworkLoggerPlugin(verbose: true)])
    
    private init() {}
    
    // We're returning a Single response with just an array with the retrieved posts.
    // You could return an Observable<PostJSON> if you need to, this is just an example.
    func getPosts() -> Single<[PostJSON]> {
        return provider.rx                              // we use the Reactive component for our provider
            .request(.getPosts)                         // we specify the call
            .filterSuccessfulStatusAndRedirectCodes()   // we tell it to only complete the call if the operation is successful, otherwise it will give us an error
            .map([PostJSON].self)                       // we map the response to our Codable objects
            .catchError { error in
                // this function catches any error that happens,
                // you can recover and continue the sequence with another observable,
                // but we're not doing this right now
                
                // todo parse error and figure out what happened
                throw ExampleError.somethingHappened
            }
    }
    
    // Here we return a Completable because we only need to know if the call is done or if there was an error.
    func deletePost(with id: Int) -> Completable {
        return provider.rx
            .request(.deletePost(id: id))
            .filterSuccessfulStatusAndRedirectCodes()
            .asObservable().ignoreElements()            // we're converting to Observable and ignoring events in order to return a Completable, which skips onNext and only maps to onCompleted
    }
    
}

enum ExampleError: Error {
    case somethingHappened
}

struct PostJSON: Codable {
    let userId: Int?
    let id: Int?
    let title: String?
    let body: String?
}

class ViewController: UIViewController {

    var disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ForumNetworkManager.shared.getPosts().subscribe { event in
            print(event[0])
        }.disposed(by: disposeBag)
    }
}

