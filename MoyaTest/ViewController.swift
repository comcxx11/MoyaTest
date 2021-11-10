//
//  ViewController.swift
//  MoyaTest
//
//  Created by 홍서진 on 2021/11/09.
//

import UIKit
import Moya
//import Alamofire
import RxSwift

enum API: String {
    case dev    = "https://jsonplaceholder.typicode.com"
    case real   = "https://jsonplaceholder2.typicode.com"
}

struct APIService {
    fileprivate let provider = MoyaProvider<ForumService>(plugins: [NetworkLoggerPlugin(verbose: true)])
    static let environment: API = .dev
}

enum ForumService {
    case getPosts
    case deletePost(id: Int)
}

// https://medium.com/@mattiacontin/better-networking-with-moya-rxswift-a90d821f1ce8
// https://pilgwon.github.io/blog/2017/10/10/RxSwift-By-Examples-3-Networking.html
// https://ios-development.tistory.com/193
extension ForumService: TargetType {
    
    
    // This is the base URL we'll be using, typically our server.
    var baseURL: URL {
        guard let url = URL(string: APIService.environment.rawValue) else {
            fatalError("invalid URL")
        }
        return url
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
    // 리퀘스트에 사용되는 파라미터 설정
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
    // 테스트용 Mock이나 Stub
    var sampleData: Data {
        return Data()
    }
    
    // 허용할 response의 타입
    var validationType: ValidationType {
        return .successCodes
    }
}

enum DecodeError: Error {
    case decodeError
}

public class NetworkManager {
    
    static let shared = NetworkManager()

    let bag = DisposeBag()

    lazy var provider: MoyaProvider<ForumService> = {
        return .init()
    }()

    public init() { }

    func process<T: Codable, E>(
        type: T.Type,
        result: Result<Response, MoyaError>,
        completion: @escaping (Result<E, Error>) -> Void
    ) {
        switch result {
        case .success(let response):
            if let data = try? JSONDecoder().decode(type, from: response.data) {
                completion(.success(data as! E))
            } else {
                completion(.failure(DecodeError.decodeError))
            }
        case .failure(let error):
            completion(.failure(error))
        }
    }
    
    public func getPost(completion: @escaping (Result<MyStatusModel.Response, Error>) -> Void) {
        provider.request(.getPosts) { result in
            print(result)
//            self.process(type: MyStatusModel.Response, result: result, completion: completion)
        }
    }
//    public func getPosts(completion: @escaping (Swift.Result<MyStatusModel.Response, Error>) -> Void) {
//        provider.request(.getPosts) { result in
//            self.process(type: MyStatusModel.self, result: result, completion: completion)
//        }
//    }
}

public struct MyStatusModel: Codable {
    public struct Request {
    }

    public struct Response: Codable {
        let userId: Int?
        let id: Int?
        let title: String?
        let body: String?
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
    
    // rx swift
    /*
    func test() {
        provider.rx.request(.userProfile("ashfurrow")).subscribe { event in
            switch event {
            case let .success(response):
                image = UIImage(data: response.data)
            case let .error(error):
                print(error)
            }
        }   
    }
    */
    
    /*
    func test2() {
        provider.request(.zen) { result in
        switch result {
            case let .success(moyaResponse):
                let data = moyaResponse.data
                let statusCode = moyaResponse.statusCode
                // do something with the response data or statusCode
            case let .failure(error):
                // this means there was a network failure - either the request
                // wasn't sent (connectivity), or no response was received (server
                // timed out).  If the server responds with a 4xx or 5xx error, that
                // will be sent as a ".success"-ful response.
            }
        }   
    }
    */
    
    // [ retry ]
    /*
    internal func getGameList(limit:Int?,offset: Int?) -> Observable<[GameViewModel]> {
        let param = ["limit": "\(limit ?? self.limit)",
            "offset": "\(offset ?? 0)"]
        return provider.rx.request(.getTopGame(param))
        	.retry(3)
        	.asObservable()
            .map { try JSONDecoder().decode(GamesStruct.self, from: $0.data) }
            .catchErrorJustReturn(nil)
            .map { $0?.top ?? [] }
            .map { $0.enumerated().map { GameViewModel(game: $1, offset: self.offset) } }
    }
    */
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
        
        NetworkManager.shared.getPost { item in
            print(item)
        }
    }
}

