//
//  ViewController.swift
//  ExchangeRateCalculator
//
//  Created by 심찬영 on 2022/01/11.
//

import UIKit
import Alamofire

class ViewController: UIViewController {
    
    // MARK: - @IBOutlet Properties
    @IBOutlet weak var lblreceiptCountry: UILabel!
    @IBOutlet weak var lblexchangeRate: UILabel!
    @IBOutlet weak var lblrequestTime: UILabel!
    @IBOutlet weak var tftransferAmount: UITextField!
    @IBOutlet weak var lblReceiveAmount: UILabel!
    @IBOutlet weak var picvCountryType: UIPickerView!
    
    // MARK: - Properties
    // 수취국가 목록
    let countryType = ["한국(KRW)", "일본(JPY)", "필리핀(PHP)"]
    var countryTypeEnglish = Array<String>()
    
    // pickerview row 수 정의
    let picvRow = 1
    
    // 파싱한 환율 정보 저장
    var quotes = [String:Double]() {
        didSet {
            // 환율정보와 갱신
            updateExchangeRate()
        }
    }
    
    // 현재 선택된 수취국가의 환율
    var currentExchangeRate = 0.0
    
    // 초기 수취국가는 KRW로 초기화
    // 현재 선택된 수취국가의 index
    var currentTypeIndex = 0 {
        // 수취국가 변경 시
        didSet {
            // 환율정보와 수취금액 갱신
            updateExchangeRate()
            tftransferAmountChanged(self)
        }
    }
    
    // 마지막 환율 정보 조회시간
    var latestRequestTime = "조회 내역 없음" {
        didSet {
            lblrequestTime.text = latestRequestTime
        }
    }
    
    // MARK: - Functions
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 수취국가 목록에서 국가 영문명만 따서 저장
        // 추후 환율 정보 요청 시 사용
        countryTypeEnglish = countryType.map{$0.suffix(4)}.map{$0.replacingOccurrences(of: ")", with: "")}
        
        // 환율 정보 요청
        getExchangeRateFromAPI()
        
        // 송금액 변경 시 tftransferAmountChanged 함수 호출하도록 설정
        tftransferAmount.addTarget(self, action: #selector(self.tftransferAmountChanged(_:)), for: .editingChanged)
        
        // tftransferAmount 키보드에 done 버튼 추가
        tftransferAmount.addDoneButton()
    }
    
    // 현재 환율 정보를 요청하여 받아오고
    // quotes dictionary에 저장하는 함수
    func getExchangeRateFromAPI() {
        // 환율 정보 API URL
        let exchangeRateUrl = "http://api.currencylayer.com/live?access_key=db519447fb745dcd410a4ab9824f67f1&format=1"
        
        // 환율 정보 요청
        AF.request(exchangeRateUrl).responseJSON { response in
            switch response.result {
            case .success:
                guard let data = response.data else {
                    self.showAlert(title: "오류", msg: "환율 정보를 가져오지 못했습니다.\ncode:100")
                    return
                }
                // 간단한 JSON 데이터이므로 Codable 사용하지 않고 파싱
                // json data 파싱
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String : Any] {
                    // success code 파싱
                    guard let success = json["success"] as? Bool else {
                        self.showAlert(title: "오류", msg: "환율 정보를 가져오지 못했습니다.\ncode:101")
                        return
                    }
                    
                    // 응답 코드가 정상이면 파싱 실행
                    if(success) {
                        // 환율 정보 파싱
                        guard let quotes = json["quotes"] as? [String:Double] else {
                            self.showAlert(title: "오류", msg: "환율 정보를 가져오지 못했습니다.\ncode:102")
                            return
                        }
                       
                        // quotes dictionary에 파싱한 데이터 저장
                        self.quotes = quotes
                        
                        // 환율 정보 요청시간 갱신
                        self.updateLatestRequestTime()
                    }
                }
            case .failure(let error):
                self.showAlert(title: "Request Error", msg: "관리자에게 문의하세요.")
                print("🚫 Alamofire Request Error\nCode:\(error._code), Message: \(error.errorDescription!)")
            }
        }
    }
    
    // 현재 수취국가에 따른 환율 정보를 View에서 갱신해주는 함수
    func updateExchangeRate() {
        // 현재 선택된 나라에 따른 환율 정보 저장
        self.currentExchangeRate = quotes["USD\(self.countryTypeEnglish[self.currentTypeIndex])"] ?? 0.0
        
        // 환율정보를 형식에 맞게 변환 후 초기화
        let refinedExchangeRate = self.numberToCommaString(self.currentExchangeRate)
        self.lblexchangeRate.text = refinedExchangeRate + " \(self.countryTypeEnglish[self.currentTypeIndex]) / USD"
    }
    
    // 조회시간 갱신 함수
    func updateLatestRequestTime() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        latestRequestTime = dateFormatter.string(from: Date()) // 현재 시간의 Date를 format에 맞춰 string으로 반환
    }
    
    // 3자리 수마다 comma를 찍어주고, 소수점 둘째 자리까지 잘라주는 함수
    func numberToCommaString(_ number: Double) -> String {
        // 3자리 수마다 comma를 찍어주고, 소수점 둘째 자리까지만 출력하기 위해 NubmerFormatter 사용
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal // ex) 1,000,000
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 2 // 허용하는 소숫점 자리수
        return formatter.string(from: NSNumber(value: number))!
    }

    // 송금액 변경 시 호출되는 함수
    @objc func tftransferAmountChanged(_ sender: Any?) {
        if let amount = tftransferAmount.text {
            // 송금액이 0 ~ 10,000 사이일 경우에 계산
            // 송금액을 모두 지우면 0으로 계산
            if((0...10000).contains(Double(amount) ?? -1) || amount.isEmpty) {
                // 현재 환율에 맞춰 수취금액 계산
                let calculatedAmount = (Double(amount) ?? 0) * currentExchangeRate
                // comma를 찍고, 소수점 둘째 자리까지 계산한 결과 저장
                let refinedAmount = numberToCommaString(calculatedAmount)
                
                lblReceiveAmount.text = "수취금액은 " + refinedAmount + " \(countryTypeEnglish[currentTypeIndex]) 입니다."
            } else { // 송금액이 올바르지 않은 경우 (문자, 범위 밖 숫자)
                tftransferAmount.text?.removeLast()
                showAlert(title: "오류", msg: "송금액이 바르지 않습니다.")
            }
        }
    }
    
    // alert을 띄우기 위해 호출하는 함수
    func showAlert(title: String = "알림", msg: String = "오류가 발생하였습니다.") {
        let alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default, handler: nil))
        self.present(alert, animated: true)
    }
}

// MARK: - Extension
extension ViewController : UIPickerViewDelegate, UIPickerViewDataSource {

    // pickerview 내부에서의 component 개수(종류) 정의
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return picvRow
    }

    // component 항목 개수 ("KRW", "JPY", "PHP" 3개)
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return countryType.count
    }

    // 각 row의 title 설정
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return countryType[row]

    }

    // 특정 row를 선택하게 되면 호출되는 함수
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // 수취국가 index 변경
        currentTypeIndex = row
        
        // 수취국가명 변경
        lblreceiptCountry.text = countryType[row]
    }
}


// UITextField에서 키보드 왼쪽 상단에 done 버튼 추가하는 함수 extension
extension UITextField {
    func addDoneButton() {
        let keyboardToolbar = UIToolbar()
        keyboardToolbar.sizeToFit()
        let doneBarButton = UIBarButtonItem(barButtonSystemItem: .done,
            target: self, action: #selector(UIView.endEditing(_:)))
        keyboardToolbar.items = [doneBarButton]
        self.inputAccessoryView = keyboardToolbar
    }
}
