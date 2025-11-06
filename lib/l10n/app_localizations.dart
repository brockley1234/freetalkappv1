import 'package:flutter/material.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_de.dart';
import 'app_localizations_zh.dart';
import 'app_localizations_ar.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_vi.dart';

abstract class AppLocalizations {
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en', ''), // English
    Locale('es', ''), // Spanish
    Locale('fr', ''), // French
    Locale('de', ''), // German
    Locale('zh', ''), // Chinese
    Locale('ar', ''), // Arabic
    Locale('hi', ''), // Hindi
    Locale('pt', ''), // Portuguese
    Locale('ja', ''), // Japanese
    Locale('ko', ''), // Korean
    Locale('it', ''), // Italian
    Locale('ru', ''), // Russian
    Locale('nl', ''), // Dutch
    Locale('tr', ''), // Turkish
    Locale('pl', ''), // Polish
    Locale('vi', ''), // Vietnamese
  ];

  // Common
  String get appName;
  String get ok;
  String get cancel;
  String get save;
  String get delete;
  String get edit;
  String get share;
  String get send;
  String get back;
  String get next;
  String get done;
  String get skip;
  String get yes;
  String get no;
  String get loading;
  String get error;
  String get success;
  String get warning;
  String get search;
  String get filter;
  String get retry;
  String get close;

  // Auth
  String get login;
  String get register;
  String get logout;
  String get email;
  String get password;
  String get confirmPassword;
  String get forgotPassword;
  String get resetPassword;
  String get createAccount;
  String get alreadyHaveAccount;
  String get dontHaveAccount;
  String get emailVerification;
  String get verifyEmail;
  String get resendVerification;
  String get username;
  String get fullName;
  String get phoneNumber;
  String get dateOfBirth;
  String get gender;
  String get bio;
  String get rememberMe;
  String get pinCode;
  String get fourDigitPin;
  String get signUp;
  String get connectWithFriends;

  // Navigation
  String get home;
  String get profile;
  String get messages;
  String get notifications;
  String get settings;
  String get explore;
  String get discover;

  // Posts
  String get createPost;
  String get editPost;
  String get deletePost;
  String get likePost;
  String get commentOnPost;
  String get sharePost;
  String get savePost;
  String get savedPosts;
  String get reportPost;
  String get post;
  String get posts;
  String get caption;
  String get addCaption;
  String get selectPhoto;
  String get selectVideo;
  String get uploadPhoto;
  String get uploadVideo;

  // Comments
  String get comments;
  String get addComment;
  String get viewAllComments;
  String get replyToComment;
  String get deleteComment;
  String get reportComment;

  // Stories
  String get story;
  String get stories;
  String get createStory;
  String get viewStory;
  String get yourStory;
  String get addToStory;

  // Messages
  String get message;
  String get newMessage;
  String get sendMessage;
  String get typeMessage;
  String get conversation;
  String get conversations;
  String get chatWith;
  String get groupChat;
  String get createGroup;
  String get addMembers;
  String get leaveGroup;
  String get deleteConversation;

  // Profile
  String get editProfile;
  String get viewProfile;
  String get followers;
  String get following;
  String get follow;
  String get unfollow;
  String get block;
  String get unblock;
  String get report;
  String get profilePicture;
  String get coverPhoto;
  String get changePicture;
  String get removePhoto;

  // Settings
  String get accountSettings;
  String get privacySettings;
  String get notificationSettings;
  String get securitySettings;
  String get languageSettings;
  String get language;
  String get changeLanguage;
  String get theme;
  String get darkMode;
  String get lightMode;
  String get systemDefault;
  String get helpAndSupport;
  String get about;
  String get termsOfService;
  String get privacyPolicy;
  String get deleteAccount;
  String get deactivateAccount;
  String get viewYourSavedPosts;
  String get changePassword;
  String get updateYourPassword;
  String get notSet;
  String get privateAccount;
  String get privateAccountDescription;
  String get showOnlineStatus;
  String get showOnlineStatusDescription;
  String get enableNotifications;
  String get pushNotifications;
  String get pushNotificationsDescription;
  String get emailNotifications;
  String get emailNotificationsDescription;
  String get appearance;
  String get version;
  String get privacyAndSecurity;
  String get blockedUsers;
  String get blockedUsersDescription;
  String get storageAndData;
  String get cacheSettings;
  String get cacheSettingsDescription;
  String get accountActions;

  // Notifications
  String get notification;
  String get likedYourPost;
  String get commentedOnYourPost;
  String get followedYou;
  String get mentionedYou;
  String get taggedYou;
  String get sharedYourPost;
  String get markAsRead;
  String get markAllAsRead;
  String get clearAll;

  // Search
  String get searchUsers;
  String get searchPosts;
  String get searchHashtags;
  String get recentSearches;
  String get clearSearchHistory;
  String get noResults;

  // Errors
  String get errorOccurred;
  String get networkError;
  String get serverError;
  String get invalidCredentials;
  String get emailAlreadyExists;
  String get usernameAlreadyExists;
  String get passwordTooShort;
  String get passwordsDontMatch;
  String get invalidEmail;
  String get requiredField;
  String get uploadFailed;
  String get deleteFailed;
  String get updateFailed;
  String get loadingFailed;

  // Success messages
  String get loginSuccess;
  String get registerSuccess;
  String get postCreated;
  String get postUpdated;
  String get postDeleted;
  String get commentAdded;
  String get commentDeleted;
  String get profileUpdated;
  String get passwordChanged;
  String get emailSent;

  // Premium
  String get premium;
  String get getPremium;
  String get premiumFeatures;
  String get subscribe;
  String get subscription;
  String get verifiedBadge;
  String get unlimitedStorage;
  String get adFree;

  // Video & Media
  String get video;
  String get videos;
  String get camera;
  String get gallery;
  String get recordVideo;
  String get takePhoto;
  String get filters;
  String get applyFilter;
  String get music;
  String get addMusic;

  // Clubs
  String get clubs;
  String get createClub;
  String get joinClub;
  String get leaveClub;
  String get clubMembers;
  String get myClubs;

  // Events
  String get events;
  String get createEvent;
  String get joinEvent;
  String get eventDetails;
  String get upcoming;
  String get past;

  // Jobs
  String get jobs;
  String get jobListings;
  String get applyForJob;
  String get myApplications;

  // Crisis Support
  String get crisis;
  String get crisisSupport;
  String get getHelp;
  String get emergencyContacts;

  // Calls
  String get call;
  String get voiceCall;
  String get videoCall;
  String get endCall;
  String get callHistory;

  // Misc
  String get pokes;
  String get pokeBack;
  String get photoAlbum;
  String get profileVisitors;
  String get recentVisitors;
  String get location;
  String get addLocation;
  String get tagPeople;
  String get taggedPeople;
  String get mentions;

  // UI Elements & Tooltips
  String get quickMenu;
  String get profileSettings;
  String get refreshFeed;
  String get update;
  String get clearAllNotifications;
  String get areYouSureClearNotifications;
  String get allNotificationsCleared;
  String get errorClearingNotifications;
  String get shareVia;
  String get sharePostUsingApps;
  String get copyLink;
  String get copyPostLink;
  String get copyText;
  String get copyPostContent;
  String get linkCopiedToClipboard;
  String get postTextCopiedToClipboard;
  String get failedToShare;
  String get failedToCopyLink;
  String get discoverAndCreateEvents;
  String get joinAndParticipateClubs;
  String get viewBookmarkedPosts;
  String get seeWhoViewedProfile;
  String get findAndPostJobs;
  String get viewPokesReceived;
  String get getHelpOrOfferSupport;
  String get upgradeToPremium;
  String get nameCannotBeEmpty;
  String get enterValidEmail;
  String get deletingPost;
  String get areYouSureDeletePost;
  String get postContentCannotBeEmpty;
  String get updatingPost;
  String get postNotFound;
  String get failedToOpenChat;
  String get profilePictureUpdated;
  String get postedNewStory;

  // Additional strings for all pages
  // Auth & Registration
  String get nameMustBeAtLeastTwoCharacters;
  String get nameCannotExceedFiftyCharacters;
  String get onlyLettersAndSpacesAllowed;
  String get pleaseEnterValidEmail;
  String get pinMustBeFourDigits;
  String get pinsDoNotMatch;
  String get securityQuestion;
  String get selectASecurityQuestion;
  String get whatIsYourMothersMaidenName;
  String get whatWasTheNameOfYourFirstPet;
  String get whatCityWereYouBornIn;
  String get whatIsYourFavoriteBook;
  String get whatWasYourChildhoodNickname;
  String get whatIsTheNameOfYourFavoriteTeacher;
  String get whatStreetDidYouGrowUpOn;
  String get whatIsYourFavoriteMovie;
  String get securityAnswer;
  String get confirmYourAnswer;
  String get iAgreeToTheTermsAndConditions;
  String get smsVerification;
  String get enterTheCodeSentToYourPhone;
  String get didNotReceiveCode;
  String get resendCode;
  String get changePin;
  String get newPin;
  String get confirmNewPin;
  String get emailRecovery;
  String get recoverAccount;

  // Chat & Messaging
  String get noConversations;
  String get noMessages;
  String get sendAMessage;
  String get selectPhotoFromGallery;
  String get takeAPhoto;
  String get selectVideoFromGallery;
  String get recordAVideo;
  String get selectDocument;
  String get selectAudio;
  String get recordAudio;
  String get sendAudioMessage;
  String get audioMessage;
  String get videoMessage;
  String get documentMessage;
  String get unsendMessage;
  String get messageUnsent;
  String get failedToUnsendMessage;
  String get typingIndicator;
  String get hasStartedTyping;
  String get messageRead;
  String get messageDelivered;
  String get messagePending;
  String get onlineStatus;
  String get away;
  String get offline;
  String get lastSeenJustNow;
  String get groupName;
  String get addGroupMembers;
  String get removeFromGroup;
  String get leaveThisGroup;
  String get groupDescriptionOptional;
  String get deleteThisConversation;
  String get areYouSureDeleteConversation;
  String get conversationDeleted;

  // Profile & User
  String get userProfile;
  String get myProfile;
  String get editMyProfile;
  String get noPostsYet;
  String get friendsSince;
  String get blockUser;
  String get unblockUser;
  String get reportThisUser;
  String get userBlocked;
  String get userUnblocked;
  String get userReported;
  String get failedToBlockUser;
  String get failedToUnblockUser;
  String get failedToReportUser;
  String get viewAllFollowers;
  String get viewAllFollowing;
  String get followUser;
  String get unfollowUser;
  String get blockThisUser;
  String get muteThisUser;

  // Posts & Content
  String get whatIsOnYourMind;
  String get writeACaption;
  String get addUpToFivePhotos;
  String get selectFromGallery;
  String get addTags;
  String get postPrivacy;
  String get public;
  String get friendsOnly;
  String get private;
  String get noOneCanSeeThisPost;
  String get commentingDisabled;
  String get sharingDisabled;
  String get removedByModeration;
  String get reportedBy;
  String get viewAllLikes;
  String get viewAllShares;
  String get reportThisPost;
  String get whyAreYouReporting;
  String get selectAReportReason;
  String get inappropriate;
  String get spam;
  String get harassment;
  String get hateSpeech;
  String get violence;
  String get selfHarm;
  String get falseInformation;
  String get copyrightViolation;
  String get other;
  String get provideMoreDetails;
  String get submitReport;
  String get thanksForReporting;
  String get yourReportHasBeenReceived;

  // Stories
  String get addPhotoToStory;
  String get addVideoToStory;
  String get viewedBy;
  String get storyExpiredIn;
  String get hours;
  String get hour;
  String get minutes;
  String get minute;
  String get seconds;
  String get second;
  String get storyViewers;
  String get hideStoryFrom;
  String get allowCommentsOnStory;

  // Notifications
  String get newFollower;
  String get newLikeOnPost;
  String get newCommentOnPost;
  String get newMessageFrom;
  String get yourPostWasRemoved;
  String get yourCommentWasRemoved;
  String get accountSuspended;
  String get suspensionReason;
  String get appealSuspension;
  String get markNotificationAsRead;

  // Settings Pages
  String get aboutReelTalk;
  String get appVersion;
  String get buildNumber;
  String get copyrightNotice;
  String get allRightsReserved;
  String get helpAndSupportCenter;
  String get frequentlyAskedQuestions;
  String get faq;
  String get faqs;
  String get commonIssuesAndSolutions;
  String get contactSupport;
  String get emailSupport;
  String get reportABug;
  String get sendFeedback;
  String get viewTermsOfService;
  String get viewPrivacyPolicy;
  String get acknowledgements;
  String get openSourceLicenses;
  String get thirdPartyLicenses;
  String get dataStorageAndCache;
  String get clearCache;
  String get clearAllCache;
  String get clearAllCacheDescription;
  String get cacheSize;
  String get imagesCache;
  String get videosCache;
  String get documentsCache;
  String get audioCache;
  String get areyouSureClearCache;
  String get thisCannnotBeUndone;
  String get cacheCleared;
  String get failedToClearCache;
  String get storageInfo;
  String get usedStorage;
  String get availableStorage;
  String get accountAndSecurity;
  String get accountInformation;
  String get updateEmail;
  String get updatePhoneNumber;
  String get updateDateOfBirth;
  String get loginActivity;
  String get activeSessions;
  String get logoutFromAllDevices;
  String get logoutFromThisDeviceOnly;
  String get logoutFromAllOtherDevices;
  String get suspendAccount;
  String get suspendAccountDescription;
  String get deleteAccountPermanently;
  String get deleteAccountWarning;
  String get thisActionCannotBeUndone;
  String get enterYourPasswordToConfirm;
  String get enterYourPINToConfirm;

  // Admin Pages
  String get adminPanel;
  String get manageUsers;
  String get manageReports;
  String get manageContent;
  String get userReports;
  String get contentReports;
  String get reportedUsers;
  String get reportedPosts;
  String get reportedComments;
  String get reportStatus;
  String get pending;
  String get reviewed;
  String get resolved;
  String get suspended;
  String get temporaryBan;
  String get permanentBan;
  String get reviewReport;
  String get takeAction;
  String get noActionNeeded;
  String get warnUser;
  String get banUserTemporarily;
  String get banUserPermanently;
  String get removeContent;
  String get actionTaken;
  String get userWasWarned;
  String get userWasBanned;
  String get contentWasRemoved;
  String get banDurationDays;
  String get reasonForAction;

  // Camera & Filters
  String get cameraFilters;
  String get facialFilters;
  String get applyFilters;
  String get removeFilters;
  String get savingPhoto;
  String get savingVideo;
  String get photoSaved;
  String get videoSaved;
  String get failedToSaveMedia;
  String get permissionDenied;
  String get cameraPermissionRequired;
  String get galleryPermissionRequired;
  String get storagePermissionRequired;
  String get enablePermissionsInSettings;

  // Media & Upload
  String get selectMedia;
  String get maximumFileSizeExceeded;
  String get unsupportedFileFormat;
  String get uploadingMedia;
  String get mediaUploadFailed;
  String get mediaUploadedSuccessfully;
  String get processingVideo;
  String get videoProcessingFailed;

  // Miscellaneous
  String get noInternet;
  String get checkYourConnection;
  String get tryAgain;
  String get somethingWentWrong;
  String get pleaseReportThisIssue;
  String get notImplementedYet;
  String get comingSoon;
  String get underMaintenance;
  String get serviceUnavailable;
  String get serverIsCurrentlyUnavailable;
  String get pleaseCheckBackLater;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return [
      'en',
      'es',
      'fr',
      'de',
      'zh',
      'ar',
      'hi',
      'pt',
      'ja',
      'ko',
      'it',
      'ru',
      'nl',
      'tr',
      'pl',
      'vi'
    ].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    switch (locale.languageCode) {
      case 'es':
        return AppLocalizationsEs();
      case 'fr':
        return AppLocalizationsFr();
      case 'de':
        return AppLocalizationsDe();
      case 'zh':
        return AppLocalizationsZh();
      case 'ar':
        return AppLocalizationsAr();
      case 'hi':
        return AppLocalizationsHi();
      case 'pt':
        return AppLocalizationsPt();
      case 'ja':
        return AppLocalizationsJa();
      case 'ko':
        return AppLocalizationsKo();
      case 'it':
        return AppLocalizationsIt();
      case 'ru':
        return AppLocalizationsRu();
      case 'nl':
        return AppLocalizationsNl();
      case 'tr':
        return AppLocalizationsTr();
      case 'pl':
        return AppLocalizationsPl();
      case 'vi':
        return AppLocalizationsVi();
      case 'en':
      default:
        return AppLocalizationsEn();
    }
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
