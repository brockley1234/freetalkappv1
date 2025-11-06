import 'app_localizations.dart';

class AppLocalizationsKo extends AppLocalizations {
  @override
  String get appName => 'ReelTalk';

  // Common
  @override
  String get ok => '확인';
  @override
  String get cancel => '취소';
  @override
  String get save => '저장';
  @override
  String get delete => '삭제';
  @override
  String get edit => '편집';
  @override
  String get share => '공유';
  @override
  String get send => '보내기';
  @override
  String get back => '뒤로';
  @override
  String get next => '다음';
  @override
  String get done => '완료';
  @override
  String get skip => '건너뛰기';
  @override
  String get yes => '예';
  @override
  String get no => '아니오';
  @override
  String get loading => '로딩 중...';
  @override
  String get error => '오류';
  @override
  String get success => '성공';
  @override
  String get warning => '경고';
  @override
  String get search => '검색';
  @override
  String get filter => '필터';
  @override
  String get retry => '다시 시도';
  @override
  String get close => '닫기';

  // Auth
  @override
  String get login => '로그인';
  @override
  String get register => '등록';
  @override
  String get logout => '로그아웃';
  @override
  String get email => '이메일';
  @override
  String get password => '비밀번호';
  @override
  String get confirmPassword => '비밀번호 확인';
  @override
  String get forgotPassword => '비밀번호를 잊으셨나요?';
  @override
  String get resetPassword => '비밀번호 재설정';
  @override
  String get createAccount => '계정 만들기';
  @override
  String get alreadyHaveAccount => '이미 계정이 있으신가요?';
  @override
  String get dontHaveAccount => '계정이 없으신가요?';
  @override
  String get emailVerification => '이메일 인증';
  @override
  String get verifyEmail => '이메일 확인';
  @override
  String get resendVerification => '인증 이메일 재전송';
  @override
  String get username => '사용자 이름';
  @override
  String get fullName => '전체 이름';
  @override
  String get phoneNumber => '전화번호';
  @override
  String get dateOfBirth => '생년월일';
  @override
  String get gender => '성별';
  @override
  String get bio => '소개';
  @override
  String get rememberMe => '로그인 상태 유지';
  @override
  String get pinCode => 'PIN 코드';
  @override
  String get fourDigitPin => '4자리 PIN';
  @override
  String get signUp => '가입하기';
  @override
  String get connectWithFriends => '친구들과 연결하고 생각을 공유하세요';

  // Navigation
  @override
  String get home => '홈';
  @override
  String get profile => '프로필';
  @override
  String get messages => '메시지';
  @override
  String get notifications => '알림';
  @override
  String get settings => '설정';
  @override
  String get explore => '탐색';
  @override
  String get discover => '발견';

  // Posts
  @override
  String get createPost => '게시물 작성';
  @override
  String get editPost => '게시물 편집';
  @override
  String get deletePost => '게시물 삭제';
  @override
  String get likePost => '좋아요';
  @override
  String get commentOnPost => '댓글';
  @override
  String get sharePost => '게시물 공유';
  @override
  String get savePost => '게시물 저장';
  @override
  String get savedPosts => '저장된 게시물';
  @override
  String get reportPost => '게시물 신고';
  @override
  String get post => '게시물';
  @override
  String get posts => '게시물';
  @override
  String get caption => '캡션';
  @override
  String get addCaption => '캡션 추가';
  @override
  String get selectPhoto => '사진 선택';
  @override
  String get selectVideo => '비디오 선택';
  @override
  String get uploadPhoto => '사진 업로드';
  @override
  String get uploadVideo => '비디오 업로드';

  // Comments
  @override
  String get comments => '댓글';
  @override
  String get addComment => '댓글 추가';
  @override
  String get viewAllComments => '모든 댓글 보기';
  @override
  String get replyToComment => '댓글에 답글';
  @override
  String get deleteComment => '댓글 삭제';
  @override
  String get reportComment => '댓글 신고';

  // Stories
  @override
  String get story => '스토리';
  @override
  String get stories => '스토리';
  @override
  String get createStory => '스토리 만들기';
  @override
  String get viewStory => '스토리 보기';
  @override
  String get yourStory => '내 스토리';
  @override
  String get addToStory => '스토리에 추가';

  // Messages
  @override
  String get message => '메시지';
  @override
  String get newMessage => '새 메시지';
  @override
  String get sendMessage => '메시지 보내기';
  @override
  String get typeMessage => '메시지를 입력하세요...';
  @override
  String get conversation => '대화';
  @override
  String get conversations => '대화';
  @override
  String get chatWith => '채팅';
  @override
  String get groupChat => '그룹 채팅';
  @override
  String get createGroup => '그룹 만들기';
  @override
  String get addMembers => '멤버 추가';
  @override
  String get leaveGroup => '그룹 나가기';
  @override
  String get deleteConversation => '대화 삭제';

  // Profile
  @override
  String get editProfile => '프로필 편집';
  @override
  String get viewProfile => '프로필 보기';
  @override
  String get followers => '팔로워';
  @override
  String get following => '팔로잉';
  @override
  String get follow => '팔로우';
  @override
  String get unfollow => '언팔로우';
  @override
  String get block => '차단';
  @override
  String get unblock => '차단 해제';
  @override
  String get report => '신고';
  @override
  String get profilePicture => '프로필 사진';
  @override
  String get coverPhoto => '커버 사진';
  @override
  String get changePicture => '사진 변경';
  @override
  String get removePhoto => '사진 제거';

  // Settings
  @override
  String get accountSettings => '계정 설정';
  @override
  String get privacySettings => '개인정보 설정';
  @override
  String get notificationSettings => '알림 설정';
  @override
  String get securitySettings => '보안 설정';
  @override
  String get languageSettings => '언어 설정';
  @override
  String get language => '언어';
  @override
  String get changeLanguage => '언어 변경';
  @override
  String get theme => '테마';
  @override
  String get darkMode => '다크 모드';
  @override
  String get lightMode => '라이트 모드';
  @override
  String get systemDefault => '시스템 기본값';
  @override
  String get helpAndSupport => '도움말 및 지원';
  @override
  String get about => '정보';
  @override
  String get termsOfService => '서비스 약관';
  @override
  String get privacyPolicy => '개인정보 처리방침';
  @override
  String get deleteAccount => '계정 삭제';
  @override
  String get deactivateAccount => '계정 비활성화';
  @override
  String get viewYourSavedPosts => '저장된 게시물 보기';
  @override
  String get changePassword => '비밀번호 변경';
  @override
  String get updateYourPassword => '비밀번호 업데이트';
  @override
  String get notSet => '설정 안 함';
  @override
  String get privateAccount => '비공개 계정';
  @override
  String get privateAccountDescription => '승인된 팔로워만 게시물을 볼 수 있습니다';
  @override
  String get showOnlineStatus => '온라인 상태 표시';
  @override
  String get showOnlineStatusDescription => '다른 사람에게 온라인 상태 표시';
  @override
  String get enableNotifications => '모든 알림 활성화 또는 비활성화';
  @override
  String get pushNotifications => '푸시 알림';
  @override
  String get pushNotificationsDescription => '푸시 알림 받기';
  @override
  String get emailNotifications => '이메일 알림';
  @override
  String get emailNotificationsDescription => '이메일로 알림 받기';
  @override
  String get appearance => '외관';
  @override
  String get version => '버전';
  @override
  String get privacyAndSecurity => '개인정보 및 보안';
  @override
  String get blockedUsers => '차단된 사용자';
  @override
  String get blockedUsersDescription => '차단된 계정 관리';
  @override
  String get storageAndData => '저장소 및 데이터';
  @override
  String get cacheSettings => '캐시 설정';
  @override
  String get cacheSettingsDescription => '캐시 데이터 및 오프라인 콘텐츠 관리';
  @override
  String get accountActions => '계정 작업';

  // Notifications
  @override
  String get notification => '알림';
  @override
  String get likedYourPost => '님이 게시물을 좋아합니다';
  @override
  String get commentedOnYourPost => '님이 게시물에 댓글을 달았습니다';
  @override
  String get followedYou => '님이 팔로우했습니다';
  @override
  String get mentionedYou => '님이 멘션했습니다';
  @override
  String get taggedYou => '님이 태그했습니다';
  @override
  String get sharedYourPost => '님이 게시물을 공유했습니다';
  @override
  String get markAsRead => '읽음으로 표시';
  @override
  String get markAllAsRead => '모두 읽음으로 표시';
  @override
  String get clearAll => '모두 지우기';

  // Search
  @override
  String get searchUsers => '사용자 검색';
  @override
  String get searchPosts => '게시물 검색';
  @override
  String get searchHashtags => '해시태그 검색';
  @override
  String get recentSearches => '최근 검색';
  @override
  String get clearSearchHistory => '검색 기록 지우기';
  @override
  String get noResults => '결과 없음';

  // Errors
  @override
  String get errorOccurred => '오류가 발생했습니다';
  @override
  String get networkError => '네트워크 오류입니다. 연결을 확인하세요.';
  @override
  String get serverError => '서버 오류입니다. 나중에 다시 시도하세요.';
  @override
  String get invalidCredentials => '잘못된 자격 증명';
  @override
  String get emailAlreadyExists => '이미 존재하는 이메일입니다';
  @override
  String get usernameAlreadyExists => '이미 존재하는 사용자 이름입니다';
  @override
  String get passwordTooShort => '비밀번호가 너무 짧습니다';
  @override
  String get passwordsDontMatch => '비밀번호가 일치하지 않습니다';
  @override
  String get invalidEmail => '유효하지 않은 이메일 주소입니다';
  @override
  String get requiredField => '이 필드는 필수입니다';
  @override
  String get uploadFailed => '업로드 실패';
  @override
  String get deleteFailed => '삭제 실패';
  @override
  String get updateFailed => '업데이트 실패';
  @override
  String get loadingFailed => '로딩 실패';

  // Success messages
  @override
  String get loginSuccess => '로그인 성공';
  @override
  String get registerSuccess => '등록 성공';
  @override
  String get postCreated => '게시물이 생성되었습니다';
  @override
  String get postUpdated => '게시물이 업데이트되었습니다';
  @override
  String get postDeleted => '게시물이 삭제되었습니다';
  @override
  String get commentAdded => '댓글이 추가되었습니다';
  @override
  String get commentDeleted => '댓글이 삭제되었습니다';
  @override
  String get profileUpdated => '프로필이 업데이트되었습니다';
  @override
  String get passwordChanged => '비밀번호가 변경되었습니다';
  @override
  String get emailSent => '이메일이 전송되었습니다';

  // Premium
  @override
  String get premium => '프리미엄';
  @override
  String get getPremium => '프리미엄 받기';
  @override
  String get premiumFeatures => '프리미엄 기능';
  @override
  String get subscribe => '구독';
  @override
  String get subscription => '구독';
  @override
  String get verifiedBadge => '인증 배지';
  @override
  String get unlimitedStorage => '무제한 저장공간';
  @override
  String get adFree => '광고 없음';

  // Video & Media
  @override
  String get video => '비디오';
  @override
  String get videos => '비디오';
  @override
  String get camera => '카메라';
  @override
  String get gallery => '갤러리';
  @override
  String get recordVideo => '비디오 녹화';
  @override
  String get takePhoto => '사진 촬영';
  @override
  String get filters => '필터';
  @override
  String get applyFilter => '필터 적용';
  @override
  String get music => '음악';
  @override
  String get addMusic => '음악 추가';

  // Clubs
  @override
  String get clubs => '클럽';
  @override
  String get createClub => '클럽 만들기';
  @override
  String get joinClub => '클럽 가입';
  @override
  String get leaveClub => '클럽 탈퇴';
  @override
  String get clubMembers => '클럽 회원';
  @override
  String get myClubs => '내 클럽';

  // Events
  @override
  String get events => '이벤트';
  @override
  String get createEvent => '이벤트 만들기';
  @override
  String get joinEvent => '이벤트 참여';
  @override
  String get eventDetails => '이벤트 세부정보';
  @override
  String get upcoming => '예정';
  @override
  String get past => '지난';

  // Jobs
  @override
  String get jobs => '구인';
  @override
  String get jobListings => '구인 목록';
  @override
  String get applyForJob => '지원하기';
  @override
  String get myApplications => '내 지원서';

  // Crisis Support
  @override
  String get crisis => '위기';
  @override
  String get crisisSupport => '위기 지원';
  @override
  String get getHelp => '도움 받기';
  @override
  String get emergencyContacts => '긴급 연락처';

  // Calls
  @override
  String get call => '통화';
  @override
  String get voiceCall => '음성 통화';
  @override
  String get videoCall => '영상 통화';
  @override
  String get endCall => '통화 종료';
  @override
  String get callHistory => '통화 기록';

  // Misc
  @override
  String get pokes => '찌르기';
  @override
  String get pokeBack => '찌르기 반환';
  @override
  String get photoAlbum => '사진 앨범';
  @override
  String get profileVisitors => '프로필 방문자';
  @override
  String get recentVisitors => '최근 방문자';
  @override
  String get location => '위치';
  @override
  String get addLocation => '위치 추가';
  @override
  String get tagPeople => '사람 태그';
  @override
  String get taggedPeople => '태그된 사람';
  @override
  String get mentions => '멘션';

  // UI Elements & Tooltips
  @override
  String get quickMenu => '빠른 메뉴';
  @override
  String get profileSettings => '프로필 설정';
  @override
  String get refreshFeed => '피드 새로고침';
  @override
  String get update => '업데이트';
  @override
  String get clearAllNotifications => '모든 알림 지우기';
  @override
  String get areYouSureClearNotifications =>
      '모든 알림을 지우시겠습니까? 이 작업은 취소할 수 없습니다.';
  @override
  String get allNotificationsCleared => '모든 알림이 지워졌습니다';
  @override
  String get errorClearingNotifications => '알림 지우기 중 오류가 발생했습니다';
  @override
  String get shareVia => '공유...';
  @override
  String get sharePostUsingApps => '다른 앱으로 게시물 공유';
  @override
  String get copyLink => '링크 복사';
  @override
  String get copyPostLink => '게시물 링크를 클립보드에 복사';
  @override
  String get copyText => '텍스트 복사';
  @override
  String get copyPostContent => '게시물 내용을 클립보드에 복사';
  @override
  String get linkCopiedToClipboard => '링크가 클립보드에 복사되었습니다';
  @override
  String get postTextCopiedToClipboard => '게시물 텍스트가 클립보드에 복사되었습니다!';
  @override
  String get failedToShare => '공유 실패';
  @override
  String get failedToCopyLink => '링크 복사 실패';
  @override
  String get discoverAndCreateEvents => '이벤트 발견 및 생성';
  @override
  String get joinAndParticipateClubs => '클럽 가입 및 참여';
  @override
  String get viewBookmarkedPosts => '북마크한 게시물 보기';
  @override
  String get seeWhoViewedProfile => '프로필 방문자 보기';
  @override
  String get findAndPostJobs => '구인 찾기 및 게시';
  @override
  String get viewPokesReceived => '받은 찌르기 보기';
  @override
  String get getHelpOrOfferSupport => '도움 받기 또는 지원 제공';
  @override
  String get upgradeToPremium => '프리미엄으로 업그레이드';
  @override
  String get nameCannotBeEmpty => '이름을 입력하세요';
  @override
  String get enterValidEmail => '유효한 이메일을 입력하세요';
  @override
  String get deletingPost => '게시물 삭제 중...';
  @override
  String get areYouSureDeletePost => '이 게시물을 삭제하시겠습니까? 이 작업은 취소할 수 없습니다.';
  @override
  String get postContentCannotBeEmpty => '게시물 내용을 입력하세요';
  @override
  String get updatingPost => '게시물 업데이트 중...';
  @override
  String get postNotFound => '게시물을 찾을 수 없습니다';
  @override
  String get failedToOpenChat => '채팅을 열 수 없습니다';
  @override
  String get profilePictureUpdated => '프로필 사진이 업데이트되었습니다!';
  @override
  String get postedNewStory => '님이 새 스토리를 게시했습니다';

  @override
  String get nameMustBeAtLeastTwoCharacters =>
      'Name must be at least 2 characters';
  @override
  String get nameCannotExceedFiftyCharacters =>
      'Name cannot exceed 50 characters';
  @override
  String get onlyLettersAndSpacesAllowed => 'Only letters and spaces allowed';
  @override
  String get pleaseEnterValidEmail => 'Please enter a valid email';
  @override
  String get pinMustBeFourDigits => 'PIN must be 4 digits';
  @override
  String get pinsDoNotMatch => 'PINs do not match';
  @override
  String get securityQuestion => 'Security Question';
  @override
  String get selectASecurityQuestion => 'Select a security question';
  @override
  String get whatWasTheNameOfYourFirstPet =>
      'What was the name of your first pet?';
  @override
  String get whatCityWereYouBornIn => 'What city were you born in?';
  @override
  String get whatIsYourFavoriteBook => 'What is your favorite book?';
  @override
  String get whatWasYourChildhoodNickname =>
      'What was your childhood nickname?';
  @override
  String get whatIsTheNameOfYourFavoriteTeacher =>
      'What is the name of your favorite teacher?';
  @override
  String get whatStreetDidYouGrowUpOn => 'What street did you grow up on?';
  @override
  String get whatIsYourFavoriteMovie => 'What is your favorite movie?';
  @override
  String get securityAnswer => 'Security Answer';
  @override
  String get confirmYourAnswer => 'Confirm your answer';
  @override
  String get iAgreeToTheTermsAndConditions =>
      'I agree to the Terms and Conditions';
  @override
  String get smsVerification => 'SMS Verification';
  @override
  String get enterTheCodeSentToYourPhone => 'Enter the code sent to your phone';
  @override
  String get resendCode => 'Resend Code';
  @override
  String get changePin => 'Change PIN';
  @override
  String get newPin => 'New PIN';
  @override
  String get confirmNewPin => 'Confirm New PIN';
  @override
  String get emailRecovery => 'Email Recovery';
  @override
  String get recoverAccount => 'Recover Account';
  @override
  String get noConversations => 'No conversations';
  @override
  String get noMessages => 'No messages';
  @override
  String get sendAMessage => 'Send a message...';
  @override
  String get selectPhotoFromGallery => 'Select photo from gallery';
  @override
  String get takeAPhoto => 'Take a photo';
  @override
  String get selectVideoFromGallery => 'Select video from gallery';
  @override
  String get recordAVideo => 'Record a video';
  @override
  String get selectDocument => 'Select document';
  @override
  String get selectAudio => 'Select audio';
  @override
  String get recordAudio => 'Record audio';
  @override
  String get sendAudioMessage => 'Send audio message';
  @override
  String get audioMessage => 'Audio message';
  @override
  String get videoMessage => 'Video message';
  @override
  String get documentMessage => 'Document message';
  @override
  String get unsendMessage => 'Unsend message';
  @override
  String get messageUnsent => 'Message unsent';
  @override
  String get failedToUnsendMessage => 'Failed to unsend message';
  @override
  String get typingIndicator => 'Typing...';
  @override
  String get hasStartedTyping => 'has started typing';
  @override
  String get messageRead => 'Message read';
  @override
  String get messageDelivered => 'Message delivered';
  @override
  String get messagePending => 'Pending';
  @override
  String get onlineStatus => 'Online';
  @override
  String get away => 'Away';
  @override
  String get offline => 'Offline';
  @override
  String get lastSeenJustNow => 'Last seen just now';
  @override
  String get groupName => 'Group name';
  @override
  String get addGroupMembers => 'Add group members';
  @override
  String get removeFromGroup => 'Remove from group';
  @override
  String get leaveThisGroup => 'Leave this group';
  @override
  String get groupDescriptionOptional => 'Group description (optional)';
  @override
  String get deleteThisConversation => 'Delete this conversation';
  @override
  String get areYouSureDeleteConversation =>
      'Are you sure you want to delete this conversation?';
  @override
  String get conversationDeleted => 'Conversation deleted';
  @override
  String get userProfile => 'User Profile';
  @override
  String get myProfile => 'My Profile';
  @override
  String get editMyProfile => 'Edit My Profile';
  @override
  String get noPostsYet => 'No posts yet';
  @override
  String get friendsSince => 'Friends since';
  @override
  String get blockUser => 'Block User';
  @override
  String get unblockUser => 'Unblock User';
  @override
  String get reportThisUser => 'Report This User';
  @override
  String get userBlocked => 'User blocked';
  @override
  String get userUnblocked => 'User unblocked';
  @override
  String get userReported => 'User reported';
  @override
  String get failedToBlockUser => 'Failed to block user';
  @override
  String get failedToUnblockUser => 'Failed to unblock user';
  @override
  String get failedToReportUser => 'Failed to report user';
  @override
  String get viewAllFollowers => 'View all followers';
  @override
  String get viewAllFollowing => 'View all following';
  @override
  String get followUser => 'Follow user';
  @override
  String get unfollowUser => 'Unfollow user';
  @override
  String get blockThisUser => 'Block this user';
  @override
  String get muteThisUser => 'Mute this user';
  @override
  String get writeACaption => 'Write a caption...';
  @override
  String get addUpToFivePhotos => 'Add up to 5 photos';
  @override
  String get selectFromGallery => 'Select from gallery';
  @override
  String get addTags => 'Add tags';
  @override
  String get postPrivacy => 'Post Privacy';
  @override
  String get public => 'Public';
  @override
  String get friendsOnly => 'Friends Only';
  @override
  String get noOneCanSeeThisPost => 'No one can see this post';
  @override
  String get commentingDisabled => 'Commenting disabled';
  @override
  String get sharingDisabled => 'Sharing disabled';
  @override
  String get removedByModeration => 'Removed by moderation';
  @override
  String get reportedBy => 'Reported by';
  @override
  String get viewAllLikes => 'View all likes';
  @override
  String get viewAllShares => 'View all shares';
  @override
  String get reportThisPost => 'Report This Post';
  @override
  String get whyAreYouReporting => 'Why are you reporting this?';
  @override
  String get selectAReportReason => 'Select a report reason';
  @override
  String get inappropriate => 'Inappropriate';
  @override
  String get spam => 'Spam';
  @override
  String get harassment => 'Harassment';
  @override
  String get hateSpeech => 'Hate Speech';
  @override
  String get violence => 'Violence';
  @override
  String get selfHarm => 'Self Harm';
  @override
  String get falseInformation => 'False Information';
  @override
  String get copyrightViolation => 'Copyright Violation';
  @override
  String get other => 'Other';
  @override
  String get provideMoreDetails => 'Provide more details';
  @override
  String get submitReport => 'Submit Report';
  @override
  String get thanksForReporting => 'Thanks for reporting';
  @override
  String get yourReportHasBeenReceived => 'Your report has been received';
  @override
  String get addPhotoToStory => 'Add photo to story';
  @override
  String get addVideoToStory => 'Add video to story';
  @override
  String get viewedBy => 'Viewed by';
  @override
  String get storyExpiredIn => 'Story expires in';
  @override
  String get hours => 'hours';
  @override
  String get hour => 'hour';
  @override
  String get minutes => 'minutes';
  @override
  String get minute => 'minute';
  @override
  String get seconds => 'seconds';
  @override
  String get second => 'second';
  @override
  String get storyViewers => 'Story viewers';
  @override
  String get hideStoryFrom => 'Hide story from';
  @override
  String get allowCommentsOnStory => 'Allow comments on story';
  @override
  String get newFollower => 'New follower';
  @override
  String get newLikeOnPost => 'New like on post';
  @override
  String get newCommentOnPost => 'New comment on post';
  @override
  String get newMessageFrom => 'New message from';
  @override
  String get yourPostWasRemoved => 'Your post was removed';
  @override
  String get yourCommentWasRemoved => 'Your comment was removed';
  @override
  String get accountSuspended => 'Account suspended';
  @override
  String get suspensionReason => 'Suspension reason';
  @override
  String get appealSuspension => 'Appeal suspension';
  @override
  String get markNotificationAsRead => 'Mark as read';
  @override
  String get aboutReelTalk => 'About ReelTalk';
  @override
  String get appVersion => 'App Version';
  @override
  String get buildNumber => 'Build Number';
  @override
  String get copyrightNotice => 'Copyright Notice';
  @override
  String get allRightsReserved => 'All rights reserved';
  @override
  String get helpAndSupportCenter => 'Help & Support Center';
  @override
  String get frequentlyAskedQuestions => 'Frequently Asked Questions';
  @override
  String get faq => 'FAQ';
  @override
  String get faqs => 'FAQs';
  @override
  String get commonIssuesAndSolutions => 'Common Issues and Solutions';
  @override
  String get contactSupport => 'Contact Support';
  @override
  String get emailSupport => 'Email Support';
  @override
  String get reportABug => 'Report a Bug';
  @override
  String get sendFeedback => 'Send Feedback';
  @override
  String get viewTermsOfService => 'View Terms of Service';
  @override
  String get viewPrivacyPolicy => 'View Privacy Policy';
  @override
  String get acknowledgements => 'Acknowledgements';
  @override
  String get openSourceLicenses => 'Open Source Licenses';
  @override
  String get thirdPartyLicenses => 'Third Party Licenses';
  @override
  String get dataStorageAndCache => 'Data Storage & Cache';
  @override
  String get clearCache => 'Clear Cache';
  @override
  String get clearAllCache => 'Clear All Cache';
  @override
  String get clearAllCacheDescription =>
      'Clear all cached data including images, videos, and documents';
  @override
  String get cacheSize => 'Cache Size';
  @override
  String get imagesCache => 'Images Cache';
  @override
  String get videosCache => 'Videos Cache';
  @override
  String get documentsCache => 'Documents Cache';
  @override
  String get audioCache => 'Audio Cache';
  @override
  String get areyouSureClearCache => 'Are you sure you want to clear cache?';
  @override
  String get thisCannnotBeUndone => 'This cannot be undone';
  @override
  String get cacheCleared => 'Cache cleared successfully';
  @override
  String get failedToClearCache => 'Failed to clear cache';
  @override
  String get storageInfo => 'Storage Information';
  @override
  String get usedStorage => 'Used Storage';
  @override
  String get availableStorage => 'Available Storage';
  @override
  String get accountAndSecurity => 'Account & Security';
  @override
  String get accountInformation => 'Account Information';
  @override
  String get updateEmail => 'Update Email';
  @override
  String get updatePhoneNumber => 'Update Phone Number';
  @override
  String get updateDateOfBirth => 'Update Date of Birth';
  @override
  String get loginActivity => 'Login Activity';
  @override
  String get activeSessions => 'Active Sessions';
  @override
  String get logoutFromAllDevices => 'Logout from all devices';
  @override
  String get logoutFromThisDeviceOnly => 'Logout from this device only';
  @override
  String get logoutFromAllOtherDevices => 'Logout from all other devices';
  @override
  String get suspendAccount => 'Suspend Account';
  @override
  String get suspendAccountDescription => 'Temporarily suspend your account';
  @override
  String get deleteAccountPermanently => 'Delete Account Permanently';
  @override
  String get deleteAccountWarning => 'Warning: This action cannot be undone';
  @override
  String get thisActionCannotBeUndone => 'This action cannot be undone';
  @override
  String get enterYourPasswordToConfirm => 'Enter your password to confirm';
  @override
  String get enterYourPINToConfirm => 'Enter your PIN to confirm';
  @override
  String get adminPanel => 'Admin Panel';
  @override
  String get manageUsers => 'Manage Users';
  @override
  String get manageReports => 'Manage Reports';
  @override
  String get manageContent => 'Manage Content';
  @override
  String get userReports => 'User Reports';
  @override
  String get contentReports => 'Content Reports';
  @override
  String get reportedUsers => 'Reported Users';
  @override
  String get reportedPosts => 'Reported Posts';
  @override
  String get reportedComments => 'Reported Comments';
  @override
  String get reportStatus => 'Report Status';
  @override
  String get pending => 'Pending';
  @override
  String get reviewed => 'Reviewed';
  @override
  String get resolved => 'Resolved';
  @override
  String get suspended => 'Suspended';
  @override
  String get temporaryBan => 'Temporary Ban';
  @override
  String get permanentBan => 'Permanent Ban';
  @override
  String get reviewReport => 'Review Report';
  @override
  String get takeAction => 'Take Action';
  @override
  String get noActionNeeded => 'No action needed';
  @override
  String get warnUser => 'Warn User';
  @override
  String get banUserTemporarily => 'Ban User Temporarily';
  @override
  String get banUserPermanently => 'Ban User Permanently';
  @override
  String get removeContent => 'Remove Content';
  @override
  String get actionTaken => 'Action taken';
  @override
  String get userWasWarned => 'User was warned';
  @override
  String get userWasBanned => 'User was banned';
  @override
  String get contentWasRemoved => 'Content was removed';
  @override
  String get banDurationDays => 'Ban duration (days)';
  @override
  String get reasonForAction => 'Reason for action';
  @override
  String get cameraFilters => 'Camera Filters';
  @override
  String get facialFilters => 'Facial Filters';
  @override
  String get applyFilters => 'Apply Filters';
  @override
  String get removeFilters => 'Remove Filters';
  @override
  String get savingPhoto => 'Saving photo...';
  @override
  String get savingVideo => 'Saving video...';
  @override
  String get photoSaved => 'Photo saved successfully';
  @override
  String get videoSaved => 'Video saved successfully';
  @override
  String get failedToSaveMedia => 'Failed to save media';
  @override
  String get permissionDenied => 'Permission denied';
  @override
  String get cameraPermissionRequired => 'Camera permission required';
  @override
  String get galleryPermissionRequired => 'Gallery permission required';
  @override
  String get storagePermissionRequired => 'Storage permission required';
  @override
  String get enablePermissionsInSettings => 'Enable permissions in settings';
  @override
  String get selectMedia => 'Select media';
  @override
  String get maximumFileSizeExceeded => 'Maximum file size exceeded';
  @override
  String get unsupportedFileFormat => 'Unsupported file format';
  @override
  String get uploadingMedia => 'Uploading media...';
  @override
  String get mediaUploadFailed => 'Media upload failed';
  @override
  String get mediaUploadedSuccessfully => 'Media uploaded successfully';
  @override
  String get processingVideo => 'Processing video...';
  @override
  String get videoProcessingFailed => 'Video processing failed';
  @override
  String get noInternet => 'No Internet';
  @override
  String get checkYourConnection => 'Check your connection';
  @override
  String get tryAgain => 'Try Again';
  @override
  String get somethingWentWrong => 'Something went wrong';
  @override
  String get pleaseReportThisIssue => 'Please report this issue';
  @override
  String get notImplementedYet => 'Not implemented yet';
  @override
  String get comingSoon => 'Coming soon';
  @override
  String get underMaintenance => 'Under maintenance';
  @override
  String get serviceUnavailable => 'Service unavailable';
  @override
  String get serverIsCurrentlyUnavailable => 'Server is currently unavailable';
  @override
  String get pleaseCheckBackLater => 'Please check back later';

  @override
  String get didNotReceiveCode => "코드를 받지 못했습니까?";

  @override
  String get private => '비공개';

  @override
  String get whatIsOnYourMind => "무엇을 생각하고 계신가요?";

  @override
  String get whatIsYourMothersMaidenName => "어머니의 처녀 시절 성은 무엇입니까?";
}
