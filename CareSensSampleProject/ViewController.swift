//
//  ViewController.swift
//  CareSensSampleProject
//
//  Created by 장근형 on 2022/01/14.
//

import UIKit

struct Constants {
    static let stopSacn = "StopScan"
    static let disconnect = "Disconnect"
}

class ViewController: UIViewController,DeviceContextDelegate,UITableViewDelegate,UITableViewDataSource {
    
    enum VIEW_STATE{
        case view_init
        case view_device_list
        case view_menu
        case view_result
        case view_disconnect
    }
    
    //View
    @IBOutlet weak var startScanButton: UIButton!
    @IBOutlet weak var stopScanButton: UIButton!
    
    //MainView
    @IBOutlet weak var mainView: UIView!
    
    //MenuView
    @IBOutlet weak var menuView: UIView!
    @IBOutlet weak var downloadAllButton: UIButton!
    @IBOutlet weak var downloadAfterButton: UIButton!
    @IBOutlet weak var seqNumTextField: UITextField!
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var deviceSNLabel: UILabel!
    @IBOutlet weak var deviceVersionLabel: UILabel!
    @IBOutlet weak var totalCountLabel: UILabel!
    @IBOutlet weak var resultTable: UITableView!
    
    //DeviceListView
    @IBOutlet weak var deviceListView: UIView!
    @IBOutlet weak var deviceListTable: UITableView!

    weak var contextDelegate:DeviceContext?
    var persistenceManager:PersistenceManager?
    
    var devicesList:Array<Dictionary<String, Any>> = [[:]]
    var pairedDevices:[String] = []
    var resultList:[String] = []
    var currentDevice:Dictionary<String,Any> = [:]
    
    var isAutoConnectSwitch:Bool = true
    
    var commandState : CALL_ACTION!
    var currentViewState : VIEW_STATE!
    
    var lastSeqNumber:Int = 0
    
    var isClickedDisconnectButton:Bool = false
    
    var context:NSManagedObjectContext?
    
    //MARK: - LifeCycle
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        contextDelegate = DeviceContext.sharedInstance() as? DeviceContext
        
        persistenceManager = PersistenceManager.shared
        
        self.context = persistenceManager?.context
        
        self.resultTable.delegate = self
        self.resultTable.dataSource = self
        
        self.deviceListTable.delegate = self
        self.deviceListTable.dataSource = self

        self.changeView(.view_init)
        self.readPairedDevices()
    }
    
    //MARK: - ContextDelegate
    func lowVersion(_ isLowVer: Bool) {
        
    }
    
    func discoveredDevice(_ devicename: CBPeripheral!, rssi RSSI: NSNumber!) {
        
        let deviceDic:[String : Any] = ["name":devicename.name ?? "",
                                        "rssi":RSSI!,
                                        "id":devicename.identifier,
                                        "peripheral":devicename!]
        
        var isDuplicatedDevice:Bool = false
        for device in devicesList {
            let new = devicename.identifier.uuidString
            let origin = device["id"] as? String
            
            if new == origin {
                isDuplicatedDevice = true
            }
        }
        
        if isDuplicatedDevice == false{
            devicesList.append(deviceDic)
            if self.pairedDevices.count > 0 {
                for item in self.pairedDevices {
                    if devicename.identifier.uuidString == item {
                        self.changeView(.view_menu)
                        currentDevice = deviceDic
                        
                        contextDelegate?.connectDevice(currentDevice["peripheral"] as? CBPeripheral, with:call_with_idle , isMgdlUnit: false)
                        return
                    }
                }
            }
        }
        
        self.deviceListTable.reloadData()
    }
    
    func bondedDevice(_ devicename: CBPeripheral!) {
        debugPrint("bondedDevice--->\(String(describing: devicename.name))")
    }
    
    func sendDeviceId(_ deviceid: String!) {
        debugPrint("sendDeviceId--->\(String(describing: deviceid))")
    }
    
    func sendDeviceVersion(_ deviceVersion: String!) {
        debugPrint("sendDeviceVersion--->\(String(describing: deviceVersion))")
        self.deviceVersionLabel.text = deviceVersion
    }
    
    func sendSerialNumber(_ deviceSN: String!) {
        self.deviceSNLabel.text = deviceSN
        self.lastSeqNumber = persistenceManager?.selectEntity(self.context!, deviceSN) ?? 0
        self.seqNumTextField.text = "\(self.lastSeqNumber + 1)"
        
        self.connect(toDevice: call_with_total_count)
    }
    
    func sendSequenceNo(_ sequenceno: Int) {
        debugPrint("sendSequenceN---->\(sequenceno)")
        self.lastSeqNumber = sequenceno
        self.seqNumTextField.text = "\(self.lastSeqNumber + 1)"
        persistenceManager?.insertEntity(self.context!, self.deviceSNLabel.text ?? "", self.lastSeqNumber)
    }
    
    func sendTotalCount(_ totalCountOfData: UInt16) {
        debugPrint("sendTotalCount---->\(totalCountOfData)")
        self.totalCountLabel.text = "\(totalCountOfData)"
        self.changeView(.view_result)
    }
    
    func sendGlucose(_ resultString: String!) {
        resultList.append(resultString)
        self.resultTable.reloadData()
        debugPrint("resultString--->\(String(describing: resultString))")
    }
    
    func sendMealFlag(_ resultString: String!) {
        resultList[resultList.count - 1] = resultString
        self.resultTable.reloadData()
    }
    
    func sendTimeSync(_ resultString: String!) {
        self.resultList = []
        self.resultList.append(resultString)
        self.resultTable.reloadData()
        
        debugPrint("resultString--->\(String(describing: resultString))")
    }
    
    func complete() {
        self.resultList.append("Complete")
        self.resultTable.reloadData()
    }
    
    func disconnect() {
        contextDelegate?.delegate = nil
        if self.stopScanButton.titleLabel?.text == Constants.disconnect{
            if currentViewState == .view_menu || isClickedDisconnectButton == true{
                self.changeView(.view_init)
                isClickedDisconnectButton = false
            }else{
                self.changeView(.view_disconnect)
            }
        }
    }
    
    func connect(toDevice command: CALL_ACTION) {
        self.commandState = command
        if commandState == call_with_download_after {
            self.contextDelegate?.setSeqNumber(calcOutput(seqNum: self.seqNumTextField.text!))
        }
        
        debugPrint("#33 connectDevice to peripheral \(String(describing: currentDevice["peripheral"]))")
        contextDelegate?.connectDevice(currentDevice["peripheral"] as? CBPeripheral, with: commandState, isMgdlUnit: false)
    }
    
    private func calcOutput(seqNum:String) -> Int{
        let seq = seqNum
        if let seq = Int(seq){
            return seq
        }else{
            return 0
        }
    }
    
    //MARK: - ButtonAction
    @IBAction func startScanAction(_ sender: Any) {
        self.changeView(.view_device_list)
        contextDelegate?.delegate = self
        self.contextDelegate?.startScan()
    }
    
    @IBAction func stopScanAction(_ sender: Any) {
        if self.stopScanButton.titleLabel?.text == Constants.disconnect{
            if self.deviceVersionLabel.text == "-"{
                self.changeView(.view_init)
            }else{
                self.connect(toDevice: call_with_disconnect)
                self.isClickedDisconnectButton = true
                self.changeView(.view_init)
            }
        }else{
            self.contextDelegate?.stopScan()
            self.changeView(.view_init)
        }
    }
    @IBAction func downloadAllAction(_ sender: Any) {
        self.connect(toDevice: call_with_download_all)
        self.changeView(.view_result)
    }
    
    @IBAction func downloadAfterAction(_ sender: Any) {
        if let text = self.seqNumTextField.text, text.isEmpty{
            //textField is empty
            
            let alert = UIAlertController(title: "Alert", message: "sequence number를 입력하세요", preferredStyle: .alert)
            let cancelAction  = UIAlertAction(title: "cancel", style: .cancel) { _ in
                alert.dismiss(animated: true, completion: nil)
            }
            
            alert.addAction(cancelAction)
            
            self.present(alert, animated: true, completion: nil)
        }else{
            //textField is not empty
            self.changeView(.view_result)
            self.connect(toDevice: call_with_download_after)
        }
        
        self.seqNumTextField.isHidden = true
    }
}

//MARK: - View
extension ViewController{
    
    func changeView(_ state:VIEW_STATE){
        switch state{
        case .view_init:
            self.deviceListTable.isHidden = true
            self.startScanButton.isEnabled = true
            self.stopScanButton.isEnabled = true
            self.mainView.isHidden = true
            self.menuView.isHidden = true
            self.stopScanButton.setTitle(Constants.stopSacn, for: .normal)
            self.currentDevice = [:]
            self.clearData()
            self.commandState = call_with_idle
            self.seqNumTextField.isHidden = false
        case .view_menu:
            self.deviceListView.isHidden = true
            self.startScanButton.isEnabled = false
            self.stopScanButton.isEnabled = true
            self.mainView.isHidden = true
            self.stopScanButton.setTitle(Constants.disconnect, for: .normal)
        case .view_device_list:
            self.deviceListView.isHidden = false
            self.deviceListTable.isHidden = false
            self.startScanButton.isEnabled = false
            self.stopScanButton.isEnabled = true
            self.mainView.isHidden = true
            self.menuView.isHidden = true
            self.clearData()
            self.deviceNameLabel.text = "-"
            self.deviceVersionLabel.text = "-"
            self.deviceSNLabel.text = "-"
            self.totalCountLabel.text = "-"
            self.seqNumTextField.text = "-"
            self.stopScanButton.setTitle(Constants.stopSacn, for: .normal)
        case .view_result:
            self.mainView.isHidden = false
            self.menuView.isHidden = false
            self.resultTable.isHidden = false
            self.deviceListView.isHidden = true
            self.deviceListTable.isHidden = true
            self.startScanButton.isEnabled = false
            self.stopScanButton.isEnabled = true
            self.stopScanButton.setTitle(Constants.disconnect, for: .normal)
            self.clearData()
        case .view_disconnect:
            self.startScanButton.isEnabled = true
            self.stopScanButton.isEnabled = false
            break
        }
        
        self.currentViewState = state
        self.seqNumTextField.resignFirstResponder()
    }
}

//MARK: - UITableViewDelegate
extension ViewController{
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if tableView == self.deviceListTable{
            return 44
        }else{
            return 88
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.deviceListTable {
            return self.devicesList.count
        }else{
            return self.resultList.count
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == self.deviceListTable{
            self.changeView(.view_menu)
            currentDevice = devicesList[indexPath.row]
            debugPrint("didSelectRowAt --->\(String(describing: currentDevice["peripheral"]))")
            self.contextDelegate?.connectDevice(currentDevice["peripheral"] as? CBPeripheral, with: call_with_idle, isMgdlUnit: false)
            
            self.deviceNameLabel.text = currentDevice["name"] as? String
            self.addPairedDevices()
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if tableView == self.deviceListTable{
            let cell:UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            let deviceName = self.devicesList[indexPath.row]["name"]
            cell.textLabel?.text = deviceName as? String
            return cell
        }else{
            let cell:UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "resultCell", for: indexPath)
            let resultStr = self.resultList[indexPath.row]
            cell.textLabel?.text = resultStr
            cell.textLabel?.numberOfLines = 0
            return cell
        }
    }
}

//MARK: - Func
extension ViewController{
    func addPairedDevices() {
        var isDuplicatedDevices:Bool = false
        NSLog("#04 addPairedDevices \(self.currentDevice["id"] as? String ?? "")" );
        
        for item in self.pairedDevices {
            if currentDevice["id"] as? String == item {
                isDuplicatedDevices = true
                break
            }
        }
        
        if isDuplicatedDevices == false {
            let deviceID:String = currentDevice["id"] as? String ?? ""
            self.pairedDevices.append(deviceID)
            self.writePairedDevices()
        }
    }
    
    func writePairedDevices() {
        let myUserDefault:UserDefaults = UserDefaults.standard
        myUserDefault.set(self.pairedDevices, forKey: "IDList")
        myUserDefault.synchronize()
    }
    
    func readPairedDevices() {
        let myUserDefault:UserDefaults = UserDefaults.standard
        let idList = myUserDefault.array(forKey: "IDList")
        self.pairedDevices = []
        self.pairedDevices.append(contentsOf: idList as? [String] ?? [])
    }
    
    func clearData(){
        self.devicesList = []
        self.resultList = []
        self.deviceListTable.reloadData()
        self.resultTable.reloadData()
    }
}

