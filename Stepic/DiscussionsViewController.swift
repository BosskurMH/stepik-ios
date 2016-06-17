//
//  DiscussionsViewController.swift
//  Stepic
//
//  Created by Alexander Karpov on 08.06.16.
//  Copyright © 2016 Alex Karpov. All rights reserved.
//

import UIKit
import SDWebImage
import DZNEmptyDataSet

enum DiscussionsEmptyDataSetState {
    case Error, Empty, None
}

class DiscussionsViewController: UIViewController {

    var discussionProxyId: String!
    var target: Int!
    
    @IBOutlet weak var tableView: UITableView!
    
    var refreshControl : UIRefreshControl? = UIRefreshControl()
    
    
    var emptyDatasetState : DiscussionsEmptyDataSetState = .None {
        didSet {
            tableView.reloadEmptyDataSet()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        print("did load")
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.emptyDataSetSource = self
        tableView.emptyDataSetDelegate = self
        emptyDatasetState = .None
        
        tableView.tableFooterView = UIView()
        
        tableView.registerNib(UINib(nibName: "DiscussionTableViewCell", bundle: nil), forCellReuseIdentifier: "DiscussionTableViewCell")
        tableView.registerNib(UINib(nibName: "LoadMoreTableViewCell", bundle: nil), forCellReuseIdentifier: "LoadMoreTableViewCell")
        
        self.title = NSLocalizedString("Discussions", comment: "")
        
        let writeCommentItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Compose, target: self, action: #selector(DiscussionsViewController.writeCommentPressed))
        self.navigationItem.rightBarButtonItem = writeCommentItem
        
        refreshControl?.addTarget(self, action: #selector(DiscussionsViewController.reloadDiscussions), forControlEvents: .ValueChanged)
        tableView.addSubview(refreshControl ?? UIView())
        refreshControl?.beginRefreshing()
        reloadDiscussions()
    }

    struct DiscussionIds {
        var all = [Int]()
        var loaded = [Int]()
        
        var leftToLoad : Int {
            return all.count - loaded.count
        }
    }
    
    struct Replies {
        var loaded = [Int : [Comment]]()
        
        func leftToLoad(comment: Comment) -> Int {
            if let loadedCount = loaded[comment.id]?.count {
                return comment.repliesIds.count - loadedCount
            } else {
                return comment.repliesIds.count
            }
        }
    }
    
    var discussionIds = DiscussionIds()
    var replies = Replies()
    var userInfos = [Int: UserInfo]()
    var discussions = [Comment]()
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func writeCommentPressed() {
        presentWriteCommentController(parent: nil)
    }
    
    func resetData(withReload: Bool) {
        discussionIds = DiscussionIds()
        replies = Replies()
        userInfos = [Int: UserInfo]()
        discussions = [Comment]()

        heightUpdateBlockForDiscussion = [:]
        countedHeightForDiscussion = [:]

        if withReload {
            tableView.reloadData()
        }
    }
    
    let discussionLoadingInterval = 20
    let repliesLoadingInterval = 20
    
    func getNextDiscussionIdsToLoad() -> [Int] {
        let startIndex = discussionIds.loaded.count
        return Array(discussionIds.all[startIndex ..< startIndex + min(discussionLoadingInterval, discussionIds.leftToLoad)])
    }
    
    func getNextReplyIdsToLoad(section: Int) -> [Int] {
        if discussions.count <= section {
            return []
        } 
        let discussion = discussions[section]
//        let startIndex = replies.loaded[discussion.id]?.count ?? 0
        let loadedIds : [Int] = replies.loaded[discussion.id]?.map({return $0.id}) ?? []
        let loadedReplies = Set<Int>(loadedIds)
        var res : [Int] = []
        
        for replyId in discussion.repliesIds {
            if !loadedReplies.contains(replyId) {
                res += [replyId]
                if res.count == repliesLoadingInterval {
                    return res
                }
            }
        }
        return res
        
//        return Array(discussion.repliesIds[startIndex ..< startIndex + min(repliesLoadingInterval, replies.leftToLoad(discussion))])
    }
    
    func loadDiscussions(ids: [Int], success: (Void -> Void)? = nil) {
        self.emptyDatasetState = .None
        ApiDataDownloader.comments.retrieve(ids, success: 
            {
                [weak self]
                retrievedDiscussions, retrievedUserInfos in 
                
                if let s = self {
                    //get superDiscussions (those who have no parents)
                    let superDiscussions = Sorter.sort(retrievedDiscussions.filter({$0.parentId == nil}), byIds: ids, canMissElements: true)
                
                    s.discussionIds.loaded += ids
                    s.discussions += superDiscussions
                    
                    for (userId, info) in retrievedUserInfos {
                        s.userInfos[userId] = info
                    }
                    
                    var changedDiscussionIds = Set<Int>()
                    //get all replies
                    for reply in retrievedDiscussions.filter({$0.parentId != nil}) {
                        if let parentId = reply.parentId {
                            if s.replies.loaded[parentId] == nil {
                                s.replies.loaded[parentId] = []
                            }
                            s.replies.loaded[parentId]? += [reply]
                            changedDiscussionIds.insert(parentId)
                        }
                    }
                    
                    //TODO: Possibly should sort all changed reply values 
                    for discussionId in changedDiscussionIds {
                        if let index = s.discussions.indexOf({$0.id == discussionId}) {
                            s.replies.loaded[discussionId]! = Sorter.sort(s.replies.loaded[discussionId]!, byIds: s.discussions[index].repliesIds, canMissElements: true)
                        }
                    }
                                        
                    success?()
                    
                    self?.emptyDatasetState = .Empty
                    
                    UIThread.performUI { 
                        s.updateTableFooterView() 
                    }
                }
            }, error: {
                [weak self]
                errorString in
                print(errorString)
                self?.emptyDatasetState = .Error
                UIThread.performUI {
                    [weak self] in
                    self?.refreshControl?.endRefreshing()
                }
            }
        )
    }
    
    func updateTableFooterView() {
        if isShowMoreDiscussionsEnabled() {
            let cell = NSBundle.mainBundle().loadNibNamed("LoadMoreTableViewCell", owner: self, options: nil)[0]  as! LoadMoreTableViewCell
            
            cell.showMoreLabel.text = NSLocalizedString("ShowMoreDiscussions", comment: "")
            let v = cell.contentView
            let tapG = UITapGestureRecognizer()
            tapG.addTarget(self, action: #selector(DiscussionsViewController.didTapTableViewFooter(_:)))
            v.addGestureRecognizer(tapG)
            
            tableView.tableFooterView = v
        } else {
            tableView.tableFooterView = nil
        }
    }
    
    var isReloading: Bool = false
    func reloadDiscussions() {
        emptyDatasetState = .None
        if isReloading {
            return
        }
        resetData(false)
        isReloading = true
        ApiDataDownloader.discussionProxies.retrieve(discussionProxyId, success: 
            {
                [weak self] 
                discussionProxy in
                self?.discussionIds.all = discussionProxy.discussionIds
                if let discussionIdsToLoad = self?.getNextDiscussionIdsToLoad() {
                    self?.loadDiscussions(discussionIdsToLoad, success: 
                        {            
                            [weak self] in
                            UIThread.performUI {
                                self?.refreshControl?.endRefreshing()
                                self?.tableView.reloadData()
//                                self?.startUpdatingHeights()
                                self?.isReloading = false
                            }
                        }
                    )
                }
            }, error: {
                [weak self]
                errorString in
                print(errorString)
                self?.isReloading = false
                self?.emptyDatasetState = .Error
                UIThread.performUI {
                    [weak self] in
                    self?.refreshControl?.endRefreshing()
                }
            }
        )
    }
    
    func isShowMoreEnabledForSection(section: Int) -> Bool {
        if discussions.count <= section  {
            return false
        }
        
        let discussion = discussions[section]
        return replies.leftToLoad(discussion) > 0 
    }
    
    func isShowMoreDiscussionsEnabled() -> Bool {
        return discussionIds.leftToLoad > 0
    }
    
    func handleSelectDiscussion(comment: Comment, completion: (Void->Void)?) {
        let alert = DiscussionAlertConstructor.getReplyAlert({
            [weak self] in
            self?.presentWriteCommentController(parent: comment.parentId ?? comment.id)
        })
        
        self.presentViewController(alert, animated: true, completion: {
            completion?()
        })
    }
    
    func presentWriteCommentController(parent parent: Int?) {
        if let writeController = ControllerHelper.instantiateViewController(identifier: "WriteCommentViewController", storyboardName: "DiscussionsStoryboard") as? WriteCommentViewController {
            writeController.parent = parent
            writeController.target = target
            writeController.delegate = self
            navigationController?.pushViewController(writeController, animated: true)
        }
    }
        
    func discussionForSection(section: Int) -> Comment? {
        if discussions.count > section {
            return discussions[section]
        } else {
            return nil
        }
    }
    
    func discussionForIndexPath(indexPath: NSIndexPath) -> Comment? {
        if let superDiscussion = discussionForSection(indexPath.section) {
            if replies.loaded[superDiscussion.id]?.count > indexPath.row {
                return replies.loaded[superDiscussion.id]![indexPath.row]
            }
        }
        return nil
    }
    
    func heightForDiscussion(comment: Comment) -> CGFloat {
        return CGFloat(DiscussionTableViewCell.estimatedHeightForTextWithComment(comment))
//        if let countedHeight = countedHeightForDiscussion[comment.id] {
//            return countedHeight
//        } else {
//            if TagDetectionUtil.isWebViewSupportNeeded(comment.text) {
//                return countingHeightForDiscussion[comment.id] ?? 0.5
//            } else {
//                countedHeightForDiscussion[comment.id] = CGFloat(DiscussionTableViewCell.estimatedHeightForTextWithComment(comment))
//                return countedHeightForDiscussion[comment.id] ?? 0.5
//            }
//        }
    }
    
    //=======HEIGHT UPDATES
    
    var heightUpdateBlockForDiscussion : [Int : Void -> Int] = [:]
    var countedHeightForDiscussion : [Int: CGFloat] = [:]
    var countingHeightForDiscussion : [Int : CGFloat] = [:]
    var nonUpdatingCountForDiscussion: [Int: Int] = [:]
    
    var isUpdating: Bool = false

    let nonUpdateMaxCount = 3
    let updateInterval = 0.5
    
    func updateHeights() {
        
        func updateHeightsNotEqual(h1: CGFloat, to h2: CGFloat) -> Bool {
            return abs(h1 - h2) > 1
        }
        
        print("updateHeight called")

        isUpdating = true
        var discussionIdsToUnsubscribe = [Int]()
        var didUpdate = false
        
        for (discussionId, heightUpdateBlock) in heightUpdateBlockForDiscussion {
            print("performing updates for discussion id \(discussionId)")
            let updateHeightBlockResult = CGFloat(heightUpdateBlock())
            print("updating height block result \(updateHeightBlockResult)")
            if countingHeightForDiscussion[discussionId] != nil {
                if updateHeightsNotEqual(updateHeightBlockResult, to: countingHeightForDiscussion[discussionId]!) && updateHeightBlockResult != 0 {
                    print("updating height from \(countingHeightForDiscussion[discussionId]!) to \(updateHeightBlockResult)")
                    countingHeightForDiscussion[discussionId] = updateHeightBlockResult
                    nonUpdatingCountForDiscussion[discussionId] = 0
                    didUpdate = true
                } else {
                    if nonUpdatingCountForDiscussion[discussionId] != nil {
                        nonUpdatingCountForDiscussion[discussionId]! += 1
                    } else {
                        nonUpdatingCountForDiscussion[discussionId] = 1
                    }
                    print("did not update height, nonUpdating count \(nonUpdatingCountForDiscussion[discussionId]!)")
                    if nonUpdatingCountForDiscussion[discussionId]! > nonUpdateMaxCount {
                        discussionIdsToUnsubscribe += [discussionId]
                    }
                }
            } else {
                print("setting countingHeight height to \(updateHeightBlockResult)")
                countingHeightForDiscussion[discussionId] = updateHeightBlockResult
                nonUpdatingCountForDiscussion[discussionId] = 0
                didUpdate = true
            }
        }
        
        for id in discussionIdsToUnsubscribe {
            print("unsubscribing discussion with id \(id)")
            nonUpdatingCountForDiscussion[id] = nil
            heightUpdateBlockForDiscussion[id] = nil
            countedHeightForDiscussion[id] = countingHeightForDiscussion[id]!
            countingHeightForDiscussion[id] = nil
        }
        
        if didUpdate {
            UIThread.performUI({
                [weak self] in
                self?.tableView.reloadData()
//                self?.tableView.beginUpdates()
//                self?.tableView.endUpdates()
            })
        }
        
        print("in end of updateHeight, \(heightUpdateBlockForDiscussion.count) left")
        
        if heightUpdateBlockForDiscussion.count > 0 {
            delay(updateInterval, closure: {
                [weak self] in
                self?.updateHeights()
            })
        } else {
            isUpdating = false
        }
    }
    
    func startUpdatingHeights() {
        if !isUpdating {
            updateHeights()
        }
    }
    
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        tableView.beginUpdates()
        tableView.endUpdates()
    }

    
    //=====================
}

extension DiscussionsViewController : UITableViewDelegate {
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if let comment = discussionForSection(section) {
            return heightForDiscussion(comment)
        } else {
            return 0.5
        }
    }
    
    func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if isShowMoreEnabledForSection(section) {
            return 50
        } else {
            return 10
        }
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if let comment = discussionForIndexPath(indexPath) {
            return heightForDiscussion(comment)
        } else {
            return 0.5
        }
    }
}

extension DiscussionsViewController : UITableViewDataSource {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return discussions.count
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return replies.loaded[discussions[section].id]?.count ?? 0
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("DiscussionTableViewCell", forIndexPath: indexPath) as! DiscussionTableViewCell
        
        if discussions.count > indexPath.section && replies.loaded[discussions[indexPath.section].id]?.count > indexPath.row {
            if let comment = replies.loaded[discussions[indexPath.section].id]?[indexPath.row] {
                if let user = userInfos[comment.userId] {
                    cell.indexPath = indexPath
                    cell.delegate = self
                    if let heightUpdateBlock = cell.initWithComment(comment, user: user) {
                        if countedHeightForDiscussion[comment.id] == nil {
                            heightUpdateBlockForDiscussion[comment.id] = heightUpdateBlock
                            startUpdatingHeights()
                        }
                    }
                }
            }
        } else {
            //TODO: Maybe should handle double refresh somehow
//            print("that was a double refresh")
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let cell = tableView.dequeueReusableCellWithIdentifier("DiscussionTableViewCell") as! DiscussionTableViewCell
        
        if discussions.count <= section  {
            return nil
        }
        
        let comment = discussions[section]
        if let user = userInfos[comment.userId] {
            if let heightUpdateBlock = cell.initWithComment(comment, user: user) {
                if countedHeightForDiscussion[comment.id] == nil {
                    heightUpdateBlockForDiscussion[comment.id] = heightUpdateBlock
                    startUpdatingHeights()
                }
            }
            let v = cell.contentView
            v.tag = section
            let tapG = UITapGestureRecognizer()
            tapG.addTarget(self, action: #selector(DiscussionsViewController.didTapHeader(_:)))
            v.addGestureRecognizer(tapG)
            
            return v
        } else {
            return nil
        }
    }
    
    func didTapTableViewFooter(gestureRecognizer: UITapGestureRecognizer) {
        if let v = gestureRecognizer.view {
            let refreshView = CellOperationsUtil.addRefreshView(v, backgroundColor: tableView.backgroundColor!)
            update(section: nil, completion: {
                refreshView.removeFromSuperview()
            })
        }
    }
    
    func didTapHeader(gestureRecognizer: UITapGestureRecognizer) {
        if let v = gestureRecognizer.view {
            let section = v.tag
            let deselectBlock = CellOperationsUtil.animateViewSelection(v)
            if discussions.count > section {
                let comment = discussions[section]
                handleSelectDiscussion(comment, completion: deselectBlock)
            } else {
                deselectBlock()
            }
        }
    }
    
    func didTapFooter(gestureRecognizer: UITapGestureRecognizer) {
        if let v = gestureRecognizer.view {
            let refreshView = CellOperationsUtil.addRefreshView(v, backgroundColor: tableView.backgroundColor!)
            update(section: v.tag, completion: {
                refreshView.removeFromSuperview()
            })
        }
    }
    
    func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if isShowMoreEnabledForSection(section) {
            let cell = NSBundle.mainBundle().loadNibNamed("LoadMoreTableViewCell", owner: self, options: nil)[0]  as! LoadMoreTableViewCell
            cell.showMoreLabel.text = NSLocalizedString("ShowMoreReplies", comment: "")
            let v = cell.contentView
            v.tag = section
            let tapG = UITapGestureRecognizer()
            tapG.addTarget(self, action: #selector(DiscussionsViewController.didTapFooter(_:)))
            v.addGestureRecognizer(tapG)
            
            return v
        } else {
            return nil
        }
    }
}

extension DiscussionsViewController : DiscussionUpdateDelegate {
    func update(section section: Int?, completion: (Void->Void)?) {
        if let s = section {
            let idsToLoad = getNextReplyIdsToLoad(s)
            loadDiscussions(idsToLoad, success: {
                [weak self] in
                UIThread.performUI {
                    self?.tableView.beginUpdates()
                    self?.tableView.reloadSections(NSIndexSet(index: s), withRowAnimation: UITableViewRowAnimation.Automatic)
                    self?.tableView.endUpdates()
//                    self?.startUpdatingHeights()
                    completion?()
                }
            })
        } else {
            let idsToLoad = getNextDiscussionIdsToLoad()
            loadDiscussions(idsToLoad, success: {
                [weak self] in
                UIThread.performUI {
                    if let s = self {
                        s.tableView.beginUpdates()
                        let sections = NSIndexSet(indexesInRange: NSMakeRange(s.discussions.count - idsToLoad.count, idsToLoad.count))
                        s.tableView.insertSections(sections, withRowAnimation: .Automatic)
                        s.tableView.endUpdates()
//                        self?.startUpdatingHeights()
                        completion?()
                    }
                }
            })
        }
    }
}

extension DiscussionsViewController : DiscussionCellDelegate {
    func didSelect(indexPath: NSIndexPath, deselectBlock: (Void -> Void)) {
        if discussions.count > indexPath.section && replies.loaded[discussions[indexPath.section].id]?.count > indexPath.row {
            if let comment = replies.loaded[discussions[indexPath.section].id]?[indexPath.row] {
                handleSelectDiscussion(comment, completion: deselectBlock)
            }
        } else {
            deselectBlock()
        }
    }
}

extension DiscussionsViewController : WriteCommentDelegate {
    func didWriteComment(comment: Comment, userInfo: UserInfo) {
        print(comment.parentId)
        userInfos[userInfo.id] = userInfo
        if let parentId = comment.parentId {
            //insert row in an existing section
            if let section = discussions.indexOf({$0.id == parentId}) {
                discussions[section].repliesIds += [comment.id]
                if replies.loaded[parentId] == nil {
                    replies.loaded[parentId] = []
                }
                replies.loaded[parentId]! += [comment]
                tableView.beginUpdates()
                let p = NSIndexPath(forRow: replies.loaded[parentId]!.count - 1, inSection: section)
                tableView.insertRowsAtIndexPaths([p], withRowAnimation: .Automatic)
                tableView.endUpdates()
            }
        } else {
            //insert section
            discussionIds.all.insert(comment.id, atIndex: 0)
            discussionIds.loaded.insert(comment.id, atIndex: 0)
            discussions.insert(comment, atIndex: 0)
            tableView.beginUpdates()
            let index = NSIndexSet(index: 0)
            tableView.insertSections(index, withRowAnimation: .Automatic)
            tableView.endUpdates()
        }
    }
}

extension DiscussionsViewController : DZNEmptyDataSetSource, DZNEmptyDataSetDelegate {
    func imageForEmptyDataSet(scrollView: UIScrollView!) -> UIImage! {
        switch emptyDatasetState {
        case .Empty:
            return Images.noCommentsWhite.size200x200
        case .Error:
            return Images.noWifiImage.white
        case .None:
            return Images.noCommentsWhite.size200x200
        }
    }
    
    func titleForEmptyDataSet(scrollView: UIScrollView!) -> NSAttributedString! {
        var text : String = ""
        switch emptyDatasetState {
        case .Empty:
            text = NSLocalizedString("NoDiscussionsTitle", comment: "")
            break
        case .Error:
            text = NSLocalizedString("ConnectionErrorTitle", comment: "")
            break
        case .None:
            text = ""
            break
        }
        
        let attributes = [NSFontAttributeName: UIFont.boldSystemFontOfSize(18.0),
                          NSForegroundColorAttributeName: UIColor.darkGrayColor()]
        
        return NSAttributedString(string: text, attributes: attributes)
    }
    
    func descriptionForEmptyDataSet(scrollView: UIScrollView!) -> NSAttributedString! {
        var text : String = ""
        
        switch emptyDatasetState {
        case .Empty:
            text = NSLocalizedString("NoDiscussionsDescription", comment: "")
            break
        case .Error:
            text = NSLocalizedString("ConnectionErrorPullToRefresh", comment: "")
            break
        case .None: 
            text = NSLocalizedString("RefreshingDiscussions", comment: "")
            break
        }
        
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .ByWordWrapping
        paragraph.alignment = .Center
        
        let attributes = [NSFontAttributeName: UIFont.systemFontOfSize(14.0),
                          NSForegroundColorAttributeName: UIColor.lightGrayColor(),
                          NSParagraphStyleAttributeName: paragraph]
        
        return NSAttributedString(string: text, attributes: attributes)
    }
    
    func verticalOffsetForEmptyDataSet(scrollView: UIScrollView!) -> CGFloat {
        //        print("offset -> \((self.navigationController?.navigationBar.bounds.height) ?? 0 + UIApplication.sharedApplication().statusBarFrame.height)")
        return 0
    }
    
    func emptyDataSetShouldAllowScroll(scrollView: UIScrollView!) -> Bool {
        return true
    }
}
