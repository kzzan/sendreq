import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local workspace preferences'**
  String get settingsSubtitle;

  /// No description provided for @savePreferences.
  ///
  /// In en, this message translates to:
  /// **'Save preferences'**
  String get savePreferences;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @appearanceDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose how sendreq matches your desktop.'**
  String get appearanceDescription;

  /// No description provided for @font.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get font;

  /// No description provided for @fontDescription.
  ///
  /// In en, this message translates to:
  /// **'Apply a readable interface font. Code and data stay monospaced.'**
  String get fontDescription;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the language used throughout sendreq.'**
  String get languageDescription;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @simplifiedChinese.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get simplifiedChinese;

  /// No description provided for @keyboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get keyboardShortcuts;

  /// No description provided for @sendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get sendRequest;

  /// No description provided for @sendShortcutDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the shortcut used by the global Send action.'**
  String get sendShortcutDescription;

  /// No description provided for @shortcutConflictWarning.
  ///
  /// In en, this message translates to:
  /// **'Ctrl+Space can conflict with input methods or editor completion.'**
  String get shortcutConflictWarning;

  /// No description provided for @customShortcut.
  ///
  /// In en, this message translates to:
  /// **'Custom shortcut'**
  String get customShortcut;

  /// No description provided for @noCustomShortcut.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get noCustomShortcut;

  /// No description provided for @recordShortcut.
  ///
  /// In en, this message translates to:
  /// **'Record shortcut'**
  String get recordShortcut;

  /// No description provided for @recordShortcutHint.
  ///
  /// In en, this message translates to:
  /// **'Press a key combination. Esc cancels.'**
  String get recordShortcutHint;

  /// No description provided for @shortcutModifierRequired.
  ///
  /// In en, this message translates to:
  /// **'Use Ctrl, Cmd, Alt, or Shift with another key.'**
  String get shortcutModifierRequired;

  /// No description provided for @shortcutReserved.
  ///
  /// In en, this message translates to:
  /// **'Ctrl/Cmd+K and Ctrl/Cmd+S are reserved.'**
  String get shortcutReserved;

  /// No description provided for @shortcutUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This shortcut cannot be used.'**
  String get shortcutUnavailable;

  /// No description provided for @shortcutUpdated.
  ///
  /// In en, this message translates to:
  /// **'Send shortcut set to {shortcut}.'**
  String shortcutUpdated(String shortcut);

  /// No description provided for @resetPreferencesDescription.
  ///
  /// In en, this message translates to:
  /// **'Reset only restores preferences. Requests, environments, and history remain unchanged.'**
  String get resetPreferencesDescription;

  /// No description provided for @resetDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset defaults'**
  String get resetDefaults;

  /// No description provided for @preferencesSaved.
  ///
  /// In en, this message translates to:
  /// **'Preferences saved'**
  String get preferencesSaved;

  /// No description provided for @preferencesSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save preferences. Retry.'**
  String get preferencesSaveFailed;

  /// No description provided for @documentationExport.
  ///
  /// In en, this message translates to:
  /// **'Documentation export'**
  String get documentationExport;

  /// No description provided for @documentationOutputDirectoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose where exported Markdown API references are written.'**
  String get documentationOutputDirectoryDescription;

  /// No description provided for @noDocumentationOutputDirectory.
  ///
  /// In en, this message translates to:
  /// **'No output folder selected'**
  String get noDocumentationOutputDirectory;

  /// No description provided for @chooseDocumentationOutputFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose documentation output folder'**
  String get chooseDocumentationOutputFolder;

  /// No description provided for @chooseOutputDirectory.
  ///
  /// In en, this message translates to:
  /// **'Choose output folder'**
  String get chooseOutputDirectory;

  /// No description provided for @changeOutputDirectory.
  ///
  /// In en, this message translates to:
  /// **'Change output folder'**
  String get changeOutputDirectory;

  /// No description provided for @defaultOutputDirectory.
  ///
  /// In en, this message translates to:
  /// **'Default folder'**
  String get defaultOutputDirectory;

  /// No description provided for @customOutputDirectory.
  ///
  /// In en, this message translates to:
  /// **'Custom folder'**
  String get customOutputDirectory;

  /// No description provided for @restoreDefaultOutputDirectory.
  ///
  /// In en, this message translates to:
  /// **'Use default output folder'**
  String get restoreDefaultOutputDirectory;

  /// No description provided for @documentationOutputDirectoryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The output folder could not be created: {error}'**
  String documentationOutputDirectoryUnavailable(String error);

  /// No description provided for @documentationOutputDirectoryPrepareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the documentation output folder. Choose another folder and try again.'**
  String get documentationOutputDirectoryPrepareFailed;

  /// No description provided for @clearOutputDirectory.
  ///
  /// In en, this message translates to:
  /// **'Clear output folder'**
  String get clearOutputDirectory;

  /// No description provided for @configureDocumentationOutputDirectory.
  ///
  /// In en, this message translates to:
  /// **'Choose a documentation output folder in Settings before exporting.'**
  String get configureDocumentationOutputDirectory;

  /// No description provided for @exportMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Export Markdown'**
  String get exportMarkdown;

  /// No description provided for @markdownExportedTo.
  ///
  /// In en, this message translates to:
  /// **'Markdown documentation exported to {path}.'**
  String markdownExportedTo(String path);

  /// No description provided for @markdownExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export Markdown documentation: {error}'**
  String markdownExportFailed(String error);

  /// No description provided for @environmentChangesSaved.
  ///
  /// In en, this message translates to:
  /// **'Environment changes saved.'**
  String get environmentChangesSaved;

  /// No description provided for @environmentChangesPending.
  ///
  /// In en, this message translates to:
  /// **'Environment changes are not saved.'**
  String get environmentChangesPending;

  /// No description provided for @environmentSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save environment changes. Retry.'**
  String get environmentSaveFailed;

  /// No description provided for @invalidHttpStatus.
  ///
  /// In en, this message translates to:
  /// **'Enter an HTTP status from 100 to 599.'**
  String get invalidHttpStatus;

  /// No description provided for @entityDataIgnoredForMethod.
  ///
  /// In en, this message translates to:
  /// **'{method} does not send a body or entity headers.'**
  String entityDataIgnoredForMethod(String method);

  /// No description provided for @collectionCreated.
  ///
  /// In en, this message translates to:
  /// **'{name} created.'**
  String collectionCreated(String name);

  /// No description provided for @folderCreated.
  ///
  /// In en, this message translates to:
  /// **'{name} created.'**
  String folderCreated(String name);

  /// No description provided for @requestRenamed.
  ///
  /// In en, this message translates to:
  /// **'Request renamed.'**
  String get requestRenamed;

  /// No description provided for @collectionRenamed.
  ///
  /// In en, this message translates to:
  /// **'Collection renamed.'**
  String get collectionRenamed;

  /// No description provided for @folderRenamed.
  ///
  /// In en, this message translates to:
  /// **'Folder renamed.'**
  String get folderRenamed;

  /// No description provided for @requestChangesSaved.
  ///
  /// In en, this message translates to:
  /// **'Request changes saved.'**
  String get requestChangesSaved;

  /// No description provided for @protocolHttp.
  ///
  /// In en, this message translates to:
  /// **'HTTP'**
  String get protocolHttp;

  /// No description provided for @protocolWebSocket.
  ///
  /// In en, this message translates to:
  /// **'WebSocket'**
  String get protocolWebSocket;

  /// No description provided for @protocolGrpc.
  ///
  /// In en, this message translates to:
  /// **'gRPC'**
  String get protocolGrpc;

  /// No description provided for @grpcConfiguration.
  ///
  /// In en, this message translates to:
  /// **'gRPC configuration'**
  String get grpcConfiguration;

  /// No description provided for @importProto.
  ///
  /// In en, this message translates to:
  /// **'Import .proto'**
  String get importProto;

  /// No description provided for @noProtoSelected.
  ///
  /// In en, this message translates to:
  /// **'No .proto file selected'**
  String get noProtoSelected;

  /// No description provided for @grpcService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get grpcService;

  /// No description provided for @grpcMethod.
  ///
  /// In en, this message translates to:
  /// **'RPC method'**
  String get grpcMethod;

  /// No description provided for @grpcTls.
  ///
  /// In en, this message translates to:
  /// **'Use TLS'**
  String get grpcTls;

  /// No description provided for @grpcMetadataHint.
  ///
  /// In en, this message translates to:
  /// **'Enabled request headers are sent as gRPC metadata.'**
  String get grpcMetadataHint;

  /// No description provided for @changeRequestProtocol.
  ///
  /// In en, this message translates to:
  /// **'Change request protocol'**
  String get changeRequestProtocol;

  /// No description provided for @changeHttpMethod.
  ///
  /// In en, this message translates to:
  /// **'Change HTTP method'**
  String get changeHttpMethod;

  /// No description provided for @workspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspace;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @collections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get collections;

  /// No description provided for @collectionActions.
  ///
  /// In en, this message translates to:
  /// **'Collection actions'**
  String get collectionActions;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @environments.
  ///
  /// In en, this message translates to:
  /// **'Environments'**
  String get environments;

  /// No description provided for @mockServers.
  ///
  /// In en, this message translates to:
  /// **'Quick Mock'**
  String get mockServers;

  /// No description provided for @documentation.
  ///
  /// In en, this message translates to:
  /// **'Documentation'**
  String get documentation;

  /// No description provided for @docs.
  ///
  /// In en, this message translates to:
  /// **'Docs'**
  String get docs;

  /// No description provided for @searchMetrics.
  ///
  /// In en, this message translates to:
  /// **'Search metrics...'**
  String get searchMetrics;

  /// No description provided for @searchRequests.
  ///
  /// In en, this message translates to:
  /// **'Search requests...'**
  String get searchRequests;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @searchHistory.
  ///
  /// In en, this message translates to:
  /// **'Search history...'**
  String get searchHistory;

  /// No description provided for @searchVariables.
  ///
  /// In en, this message translates to:
  /// **'Search variables...'**
  String get searchVariables;

  /// No description provided for @searchMocks.
  ///
  /// In en, this message translates to:
  /// **'Search Quick Mock...'**
  String get searchMocks;

  /// No description provided for @searchDocumentation.
  ///
  /// In en, this message translates to:
  /// **'Search documentation...'**
  String get searchDocumentation;

  /// No description provided for @searchSettings.
  ///
  /// In en, this message translates to:
  /// **'Search settings...'**
  String get searchSettings;

  /// No description provided for @openCommandPalette.
  ///
  /// In en, this message translates to:
  /// **'Open command palette'**
  String get openCommandPalette;

  /// No description provided for @activeEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Active environment'**
  String get activeEnvironment;

  /// No description provided for @activeEnvironmentShort.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE ENV'**
  String get activeEnvironmentShort;

  /// No description provided for @variablesResolveBeforeSend.
  ///
  /// In en, this message translates to:
  /// **'Variables resolve before sending.'**
  String get variablesResolveBeforeSend;

  /// No description provided for @openDocumentation.
  ///
  /// In en, this message translates to:
  /// **'Open documentation'**
  String get openDocumentation;

  /// No description provided for @saveActiveResource.
  ///
  /// In en, this message translates to:
  /// **'Save active resource'**
  String get saveActiveResource;

  /// No description provided for @noSaveableChanges.
  ///
  /// In en, this message translates to:
  /// **'No saveable changes'**
  String get noSaveableChanges;

  /// No description provided for @minimizeWindow.
  ///
  /// In en, this message translates to:
  /// **'Minimize window'**
  String get minimizeWindow;

  /// No description provided for @closeWindow.
  ///
  /// In en, this message translates to:
  /// **'Close window'**
  String get closeWindow;

  /// No description provided for @desktopMvp.
  ///
  /// In en, this message translates to:
  /// **'desktop mvp'**
  String get desktopMvp;

  /// No description provided for @noRequestsYet.
  ///
  /// In en, this message translates to:
  /// **'No requests yet'**
  String get noRequestsYet;

  /// No description provided for @createRequestToStart.
  ///
  /// In en, this message translates to:
  /// **'Create a request to start testing an API.'**
  String get createRequestToStart;

  /// No description provided for @newRequest.
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get newRequest;

  /// No description provided for @request.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get request;

  /// No description provided for @response.
  ///
  /// In en, this message translates to:
  /// **'Response'**
  String get response;

  /// No description provided for @commandPalette.
  ///
  /// In en, this message translates to:
  /// **'Command palette'**
  String get commandPalette;

  /// No description provided for @searchCommands.
  ///
  /// In en, this message translates to:
  /// **'Search commands'**
  String get searchCommands;

  /// No description provided for @noMatchingResources.
  ///
  /// In en, this message translates to:
  /// **'No matching resources'**
  String get noMatchingResources;

  /// No description provided for @sendActiveRequest.
  ///
  /// In en, this message translates to:
  /// **'Send active request'**
  String get sendActiveRequest;

  /// No description provided for @environmentVariables.
  ///
  /// In en, this message translates to:
  /// **'Environment variables'**
  String get environmentVariables;

  /// No description provided for @environmentConfiguration.
  ///
  /// In en, this message translates to:
  /// **'ENVIRONMENT CONFIGURATION'**
  String get environmentConfiguration;

  /// No description provided for @environmentUsesName.
  ///
  /// In en, this message translates to:
  /// **'The active request resolves variables with {name}'**
  String environmentUsesName(String name);

  /// No description provided for @returnToRequest.
  ///
  /// In en, this message translates to:
  /// **'Back to request'**
  String get returnToRequest;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @noChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes'**
  String get noChanges;

  /// No description provided for @currentEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Current environment'**
  String get currentEnvironment;

  /// No description provided for @selectCurrentEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Select current environment'**
  String get selectCurrentEnvironment;

  /// No description provided for @newEnvironment.
  ///
  /// In en, this message translates to:
  /// **'New environment'**
  String get newEnvironment;

  /// No description provided for @createEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Create environment'**
  String get createEnvironment;

  /// No description provided for @renameEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Rename environment'**
  String get renameEnvironment;

  /// No description provided for @deleteEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Delete environment'**
  String get deleteEnvironment;

  /// No description provided for @environmentName.
  ///
  /// In en, this message translates to:
  /// **'Environment name'**
  String get environmentName;

  /// No description provided for @deleteEnvironmentConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} and all of its variables?'**
  String deleteEnvironmentConfirmation(String name);

  /// No description provided for @lastEnvironmentRequired.
  ///
  /// In en, this message translates to:
  /// **'Keep at least one environment for variable resolution.'**
  String get lastEnvironmentRequired;

  /// No description provided for @environmentNameMustBeUnique.
  ///
  /// In en, this message translates to:
  /// **'Enter a unique environment name.'**
  String get environmentNameMustBeUnique;

  /// No description provided for @environmentActions.
  ///
  /// In en, this message translates to:
  /// **'Environment actions'**
  String get environmentActions;

  /// No description provided for @scope.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get scope;

  /// No description provided for @variableName.
  ///
  /// In en, this message translates to:
  /// **'Variable name'**
  String get variableName;

  /// No description provided for @currentValue.
  ///
  /// In en, this message translates to:
  /// **'Current value'**
  String get currentValue;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @addVariable.
  ///
  /// In en, this message translates to:
  /// **'Add variable'**
  String get addVariable;

  /// No description provided for @addParameterFromEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Add parameter from environment'**
  String get addParameterFromEnvironment;

  /// No description provided for @managedByAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Managed by Auth'**
  String get managedByAuthentication;

  /// No description provided for @environmentAuditNote.
  ///
  /// In en, this message translates to:
  /// **'Saving changes creates a lightweight revision record. Full audit diffs will be available in a later release.'**
  String get environmentAuditNote;

  /// No description provided for @variableValue.
  ///
  /// In en, this message translates to:
  /// **'Variable value'**
  String get variableValue;

  /// No description provided for @toggleSecretVisibility.
  ///
  /// In en, this message translates to:
  /// **'Show or hide secret'**
  String get toggleSecretVisibility;

  /// No description provided for @changeVariableType.
  ///
  /// In en, this message translates to:
  /// **'Change variable type'**
  String get changeVariableType;

  /// No description provided for @deleteVariable.
  ///
  /// In en, this message translates to:
  /// **'Delete variable'**
  String get deleteVariable;

  /// No description provided for @requiredTokenVariable.
  ///
  /// In en, this message translates to:
  /// **'Token is required for every environment'**
  String get requiredTokenVariable;

  /// No description provided for @requiredEnvironmentBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Every environment requires a base URL'**
  String get requiredEnvironmentBaseUrl;

  /// No description provided for @variableTypeString.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get variableTypeString;

  /// No description provided for @variableTypeNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get variableTypeNumber;

  /// No description provided for @variableTypeBoolean.
  ///
  /// In en, this message translates to:
  /// **'Boolean'**
  String get variableTypeBoolean;

  /// No description provided for @variableTypeSecret.
  ///
  /// In en, this message translates to:
  /// **'Secret'**
  String get variableTypeSecret;

  /// No description provided for @authenticationType.
  ///
  /// In en, this message translates to:
  /// **'Authentication type'**
  String get authenticationType;

  /// No description provided for @authenticationSource.
  ///
  /// In en, this message translates to:
  /// **'Authentication source'**
  String get authenticationSource;

  /// No description provided for @inheritEnvironmentAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Inherit environment'**
  String get inheritEnvironmentAuthentication;

  /// No description provided for @requestSpecificAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Request-specific'**
  String get requestSpecificAuthentication;

  /// No description provided for @configureEnvironmentAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Configure environment authentication'**
  String get configureEnvironmentAuthentication;

  /// No description provided for @clearUnusedAuthenticationVariables.
  ///
  /// In en, this message translates to:
  /// **'Clear unused credentials'**
  String get clearUnusedAuthenticationVariables;

  /// No description provided for @clearUnusedAuthenticationVariablesTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear unused credentials?'**
  String get clearUnusedAuthenticationVariablesTitle;

  /// No description provided for @clearUnusedAuthenticationVariablesMessage.
  ///
  /// In en, this message translates to:
  /// **'This permanently removes: {variables}'**
  String clearUnusedAuthenticationVariablesMessage(String variables);

  /// No description provided for @clearCredentials.
  ///
  /// In en, this message translates to:
  /// **'Clear credentials'**
  String get clearCredentials;

  /// No description provided for @switchEnvironmentAuthenticationTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch authentication method?'**
  String get switchEnvironmentAuthenticationTitle;

  /// No description provided for @switchEnvironmentAuthenticationMessage.
  ///
  /// In en, this message translates to:
  /// **'The current authentication credentials will be removed from this environment.'**
  String get switchEnvironmentAuthenticationMessage;

  /// No description provided for @switchAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Switch authentication'**
  String get switchAuthentication;

  /// No description provided for @basicAuth.
  ///
  /// In en, this message translates to:
  /// **'Basic auth'**
  String get basicAuth;

  /// No description provided for @apiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get apiKey;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @apiKeyName.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get apiKeyName;

  /// No description provided for @apiKeyValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get apiKeyValue;

  /// No description provided for @sendIn.
  ///
  /// In en, this message translates to:
  /// **'Send in'**
  String get sendIn;

  /// No description provided for @basicAuthenticationStored.
  ///
  /// In en, this message translates to:
  /// **'Authorization is generated only when this request runs.'**
  String get basicAuthenticationStored;

  /// No description provided for @apiKeyAuthenticationStored.
  ///
  /// In en, this message translates to:
  /// **'This API key is generated only when this request runs.'**
  String get apiKeyAuthenticationStored;

  /// No description provided for @noMockDraft.
  ///
  /// In en, this message translates to:
  /// **'No Quick Mock yet'**
  String get noMockDraft;

  /// No description provided for @mockDraftDescription.
  ///
  /// In en, this message translates to:
  /// **'Available for this session only. Removed when sendreq closes.'**
  String get mockDraftDescription;

  /// No description provided for @newMock.
  ///
  /// In en, this message translates to:
  /// **'New Quick Mock'**
  String get newMock;

  /// No description provided for @createMockFromResponse.
  ///
  /// In en, this message translates to:
  /// **'Use response for Quick Mock'**
  String get createMockFromResponse;

  /// No description provided for @manualMock.
  ///
  /// In en, this message translates to:
  /// **'Manually configured response'**
  String get manualMock;

  /// No description provided for @openCollections.
  ///
  /// In en, this message translates to:
  /// **'Open collections'**
  String get openCollections;

  /// No description provided for @mockDraft.
  ///
  /// In en, this message translates to:
  /// **'Quick Mock'**
  String get mockDraft;

  /// No description provided for @fromLatestResponse.
  ///
  /// In en, this message translates to:
  /// **'Based on the latest response'**
  String get fromLatestResponse;

  /// No description provided for @returnToResponse.
  ///
  /// In en, this message translates to:
  /// **'Back to response'**
  String get returnToResponse;

  /// No description provided for @responseExample.
  ///
  /// In en, this message translates to:
  /// **'Response example'**
  String get responseExample;

  /// No description provided for @mockResponse.
  ///
  /// In en, this message translates to:
  /// **'Quick Mock response'**
  String get mockResponse;

  /// No description provided for @mockLoopbackNote.
  ///
  /// In en, this message translates to:
  /// **'Matches method and path. Query parameters are ignored.'**
  String get mockLoopbackNote;

  /// No description provided for @localRuntime.
  ///
  /// In en, this message translates to:
  /// **'Local runtime'**
  String get localRuntime;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running;

  /// No description provided for @stopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get stopped;

  /// No description provided for @stopServer.
  ///
  /// In en, this message translates to:
  /// **'Stop Quick Mock'**
  String get stopServer;

  /// No description provided for @startServer.
  ///
  /// In en, this message translates to:
  /// **'Start Quick Mock'**
  String get startServer;

  /// No description provided for @copyMockAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy Quick Mock address'**
  String get copyMockAddress;

  /// No description provided for @mockAddressCopied.
  ///
  /// In en, this message translates to:
  /// **'Quick Mock address copied.'**
  String get mockAddressCopied;

  /// No description provided for @noDocumentationDraft.
  ///
  /// In en, this message translates to:
  /// **'No documentation draft yet'**
  String get noDocumentationDraft;

  /// No description provided for @documentationDraftDescription.
  ///
  /// In en, this message translates to:
  /// **'Send a request, then generate API documentation from its response.'**
  String get documentationDraftDescription;

  /// No description provided for @documentationDraft.
  ///
  /// In en, this message translates to:
  /// **'Documentation draft'**
  String get documentationDraft;

  /// No description provided for @fromResponseSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Generated from a response snapshot'**
  String get fromResponseSnapshot;

  /// No description provided for @tryIt.
  ///
  /// In en, this message translates to:
  /// **'Try it'**
  String get tryIt;

  /// No description provided for @copyApiReference.
  ///
  /// In en, this message translates to:
  /// **'Copy API reference'**
  String get copyApiReference;

  /// No description provided for @apiReferenceCopied.
  ///
  /// In en, this message translates to:
  /// **'API reference copied.'**
  String get apiReferenceCopied;

  /// No description provided for @apiReference.
  ///
  /// In en, this message translates to:
  /// **'API reference'**
  String get apiReference;

  /// No description provided for @curlCopied.
  ///
  /// In en, this message translates to:
  /// **'cURL copied.'**
  String get curlCopied;

  /// No description provided for @curl.
  ///
  /// In en, this message translates to:
  /// **'cURL'**
  String get curl;

  /// No description provided for @responseExampleCopied.
  ///
  /// In en, this message translates to:
  /// **'Response example copied.'**
  String get responseExampleCopied;

  /// No description provided for @copyNamedValue.
  ///
  /// In en, this message translates to:
  /// **'Copy {name}'**
  String copyNamedValue(String name);

  /// No description provided for @responseTitle.
  ///
  /// In en, this message translates to:
  /// **'Response'**
  String get responseTitle;

  /// No description provided for @executionSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Execution snapshot · {environment}'**
  String executionSnapshot(String environment);

  /// No description provided for @unknownEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Unknown environment'**
  String get unknownEnvironment;

  /// No description provided for @awaitingCurrentRequest.
  ///
  /// In en, this message translates to:
  /// **'Waiting to send the current request'**
  String get awaitingCurrentRequest;

  /// No description provided for @executionResult.
  ///
  /// In en, this message translates to:
  /// **'Execution result for this request'**
  String get executionResult;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @originalRequestDeleted.
  ///
  /// In en, this message translates to:
  /// **'The original request was deleted and cannot be reopened.'**
  String get originalRequestDeleted;

  /// No description provided for @body.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get body;

  /// No description provided for @responseHeaders.
  ///
  /// In en, this message translates to:
  /// **'Response headers'**
  String get responseHeaders;

  /// No description provided for @requestSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Request snapshot'**
  String get requestSnapshot;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get duration;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @copyResponseBody.
  ///
  /// In en, this message translates to:
  /// **'Copy response body'**
  String get copyResponseBody;

  /// No description provided for @downloadResponseBody.
  ///
  /// In en, this message translates to:
  /// **'Download response body'**
  String get downloadResponseBody;

  /// No description provided for @generateDocumentation.
  ///
  /// In en, this message translates to:
  /// **'Generate documentation'**
  String get generateDocumentation;

  /// No description provided for @createMock.
  ///
  /// In en, this message translates to:
  /// **'Use response for Quick Mock'**
  String get createMock;

  /// No description provided for @replaceQuickMockTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace Quick Mock?'**
  String get replaceQuickMockTitle;

  /// No description provided for @replaceQuickMockMessage.
  ///
  /// In en, this message translates to:
  /// **'The current response configuration will be replaced.'**
  String get replaceQuickMockMessage;

  /// No description provided for @replaceQuickMock.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replaceQuickMock;

  /// No description provided for @responseBodyCopied.
  ///
  /// In en, this message translates to:
  /// **'Response body copied.'**
  String get responseBodyCopied;

  /// No description provided for @responseSavedAt.
  ///
  /// In en, this message translates to:
  /// **'Response saved to {path}'**
  String responseSavedAt(String path);

  /// No description provided for @responseSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save response: {message}'**
  String responseSaveFailed(String message);

  /// No description provided for @responseBody.
  ///
  /// In en, this message translates to:
  /// **'Response body'**
  String get responseBody;

  /// No description provided for @validJson.
  ///
  /// In en, this message translates to:
  /// **'Valid JSON'**
  String get validJson;

  /// No description provided for @plainText.
  ///
  /// In en, this message translates to:
  /// **'Plain text'**
  String get plainText;

  /// No description provided for @formattedView.
  ///
  /// In en, this message translates to:
  /// **'Formatted'**
  String get formattedView;

  /// No description provided for @rawView.
  ///
  /// In en, this message translates to:
  /// **'Raw'**
  String get rawView;

  /// No description provided for @responseLineCount.
  ///
  /// In en, this message translates to:
  /// **'{count} lines'**
  String responseLineCount(int count);

  /// No description provided for @copyDisplayedResponse.
  ///
  /// In en, this message translates to:
  /// **'Copy displayed response'**
  String get copyDisplayedResponse;

  /// No description provided for @displayedResponseCopied.
  ///
  /// In en, this message translates to:
  /// **'Displayed response copied.'**
  String get displayedResponseCopied;

  /// No description provided for @noResponseYet.
  ///
  /// In en, this message translates to:
  /// **'No response yet'**
  String get noResponseYet;

  /// No description provided for @noResponseBody.
  ///
  /// In en, this message translates to:
  /// **'This execution has no response body'**
  String get noResponseBody;

  /// No description provided for @responseAwaitingDescription.
  ///
  /// In en, this message translates to:
  /// **'Send the current request to view its status, duration, and response content here.'**
  String get responseAwaitingDescription;

  /// No description provided for @requestAtExecution.
  ///
  /// In en, this message translates to:
  /// **'Request at execution'**
  String get requestAtExecution;

  /// No description provided for @environmentValue.
  ///
  /// In en, this message translates to:
  /// **'Environment  {name}'**
  String environmentValue(String name);

  /// No description provided for @requestHeaders.
  ///
  /// In en, this message translates to:
  /// **'Request headers'**
  String get requestHeaders;

  /// No description provided for @requestBody.
  ///
  /// In en, this message translates to:
  /// **'Request body'**
  String get requestBody;

  /// No description provided for @empty.
  ///
  /// In en, this message translates to:
  /// **'(empty)'**
  String get empty;

  /// No description provided for @sendingRequest.
  ///
  /// In en, this message translates to:
  /// **'Sending {name}'**
  String sendingRequest(String name);

  /// No description provided for @usingEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Using environment: {name}'**
  String usingEnvironment(String name);

  /// No description provided for @cancelSend.
  ///
  /// In en, this message translates to:
  /// **'Cancel send'**
  String get cancelSend;

  /// No description provided for @errorDetailsCopied.
  ///
  /// In en, this message translates to:
  /// **'Error details copied.'**
  String get errorDetailsCopied;

  /// No description provided for @copyErrorDetails.
  ///
  /// In en, this message translates to:
  /// **'Copy error details'**
  String get copyErrorDetails;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @startupRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Local data needs recovery'**
  String get startupRecoveryTitle;

  /// No description provided for @startupRecoveryDescription.
  ///
  /// In en, this message translates to:
  /// **'sendreq kept the original files unchanged. Repair the JSON or folder access, then retry migration.'**
  String get startupRecoveryDescription;

  /// No description provided for @returnToRequestEditor.
  ///
  /// In en, this message translates to:
  /// **'Back to request editor'**
  String get returnToRequestEditor;

  /// No description provided for @unsavedRequest.
  ///
  /// In en, this message translates to:
  /// **'Unsaved request'**
  String get unsavedRequest;

  /// No description provided for @saveRequestBeforeClose.
  ///
  /// In en, this message translates to:
  /// **'Save changes to {name} before closing?'**
  String saveRequestBeforeClose(String name);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardChanges;

  /// No description provided for @saveAndClose.
  ///
  /// In en, this message translates to:
  /// **'Save and close'**
  String get saveAndClose;

  /// No description provided for @discardUnsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get discardUnsavedChanges;

  /// No description provided for @discardChangesForRequest.
  ///
  /// In en, this message translates to:
  /// **'Changes to {name} cannot be recovered.'**
  String discardChangesForRequest(String name);

  /// No description provided for @continueEditing.
  ///
  /// In en, this message translates to:
  /// **'Continue editing'**
  String get continueEditing;

  /// No description provided for @closeRequest.
  ///
  /// In en, this message translates to:
  /// **'Close {name}'**
  String closeRequest(String name);

  /// No description provided for @closeOtherTabs.
  ///
  /// In en, this message translates to:
  /// **'Close other tabs'**
  String get closeOtherTabs;

  /// No description provided for @closeTabsToLeft.
  ///
  /// In en, this message translates to:
  /// **'Close tabs to the left'**
  String get closeTabsToLeft;

  /// No description provided for @closeTabsToRight.
  ///
  /// In en, this message translates to:
  /// **'Close tabs to the right'**
  String get closeTabsToRight;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @missingEnvironmentVariables.
  ///
  /// In en, this message translates to:
  /// **'Missing environment variables: {variables}'**
  String missingEnvironmentVariables(String variables);

  /// No description provided for @openEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Open environment'**
  String get openEnvironment;

  /// No description provided for @unsaved.
  ///
  /// In en, this message translates to:
  /// **'Unsaved'**
  String get unsaved;

  /// No description provided for @discardUnsavedChangesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes'**
  String get discardUnsavedChangesTooltip;

  /// No description provided for @queryParameters.
  ///
  /// In en, this message translates to:
  /// **'Query parameters'**
  String get queryParameters;

  /// No description provided for @protocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get protocol;

  /// No description provided for @authorization.
  ///
  /// In en, this message translates to:
  /// **'Authorization'**
  String get authorization;

  /// No description provided for @newMessages.
  ///
  /// In en, this message translates to:
  /// **'{count} new'**
  String newMessages(int count);

  /// No description provided for @webSocketState.
  ///
  /// In en, this message translates to:
  /// **'WebSocket {state}'**
  String webSocketState(String state);

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connecting;

  /// No description provided for @closing.
  ///
  /// In en, this message translates to:
  /// **'Closing'**
  String get closing;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get connectionError;

  /// No description provided for @formatJson.
  ///
  /// In en, this message translates to:
  /// **'Format JSON'**
  String get formatJson;

  /// No description provided for @connectBeforeSending.
  ///
  /// In en, this message translates to:
  /// **'Connect before sending a message.'**
  String get connectBeforeSending;

  /// No description provided for @selectProtobufBeforeSending.
  ///
  /// In en, this message translates to:
  /// **'Select a Protobuf schema and message type before sending.'**
  String get selectProtobufBeforeSending;

  /// No description provided for @sendWithShortcut.
  ///
  /// In en, this message translates to:
  /// **'Ctrl+Enter to send'**
  String get sendWithShortcut;

  /// No description provided for @messagePayload.
  ///
  /// In en, this message translates to:
  /// **'Message payload'**
  String get messagePayload;

  /// No description provided for @base64Bytes.
  ///
  /// In en, this message translates to:
  /// **'Base64 encoded bytes'**
  String get base64Bytes;

  /// No description provided for @protobufJsonPayload.
  ///
  /// In en, this message translates to:
  /// **'JSON for the selected Protobuf message type'**
  String get protobufJsonPayload;

  /// No description provided for @executionHistory.
  ///
  /// In en, this message translates to:
  /// **'Execution history'**
  String get executionHistory;

  /// No description provided for @latestRequestSnapshots.
  ///
  /// In en, this message translates to:
  /// **'Latest request snapshots'**
  String get latestRequestSnapshots;

  /// No description provided for @historyExecutionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} executions'**
  String historyExecutionCount(int count);

  /// No description provided for @historyTimeline.
  ///
  /// In en, this message translates to:
  /// **'Execution timeline'**
  String get historyTimeline;

  /// No description provided for @historyExecutionDetail.
  ///
  /// In en, this message translates to:
  /// **'Execution detail'**
  String get historyExecutionDetail;

  /// No description provided for @historyTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get historyTotal;

  /// No description provided for @historyAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get historyAll;

  /// No description provided for @historySuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get historySuccess;

  /// No description provided for @historyFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get historyFailed;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No executions yet.'**
  String get historyEmpty;

  /// No description provided for @historyNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No executions match this search.'**
  String get historyNoSearchResults;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get clearHistory;

  /// No description provided for @clearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear execution history?'**
  String get clearHistoryTitle;

  /// No description provided for @clearHistoryMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes all execution records from the current session.'**
  String get clearHistoryMessage;

  /// No description provided for @historyCleared.
  ///
  /// In en, this message translates to:
  /// **'Execution history cleared.'**
  String get historyCleared;

  /// No description provided for @dashboardForEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Last 24 hours, {name} workspace'**
  String dashboardForEnvironment(String name);

  /// No description provided for @quickStart.
  ///
  /// In en, this message translates to:
  /// **'Quick start'**
  String get quickStart;

  /// No description provided for @quickStartDescription.
  ///
  /// In en, this message translates to:
  /// **'Start a draft or import an existing API definition.'**
  String get quickStartDescription;

  /// No description provided for @requestVolume.
  ///
  /// In en, this message translates to:
  /// **'Request volume'**
  String get requestVolume;

  /// No description provided for @environmentHealth.
  ///
  /// In en, this message translates to:
  /// **'Environment health'**
  String get environmentHealth;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get active;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'READY'**
  String get ready;

  /// No description provided for @noFiles.
  ///
  /// In en, this message translates to:
  /// **'No files'**
  String get noFiles;

  /// No description provided for @selectedFileCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedFileCount(int count);

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @fieldCount.
  ///
  /// In en, this message translates to:
  /// **'{count} fields'**
  String fieldCount(int count);

  /// No description provided for @multipartFieldsDescription.
  ///
  /// In en, this message translates to:
  /// **'Add text values only when the endpoint requires them.'**
  String get multipartFieldsDescription;

  /// No description provided for @newCollection.
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get newCollection;

  /// No description provided for @loadDemoExample.
  ///
  /// In en, this message translates to:
  /// **'Load Demo Example'**
  String get loadDemoExample;

  /// No description provided for @importOpenApi.
  ///
  /// In en, this message translates to:
  /// **'Import OpenAPI'**
  String get importOpenApi;

  /// No description provided for @exportOpenApi.
  ///
  /// In en, this message translates to:
  /// **'Export OpenAPI'**
  String get exportOpenApi;

  /// No description provided for @importOpenApiJson.
  ///
  /// In en, this message translates to:
  /// **'Import OpenAPI JSON'**
  String get importOpenApiJson;

  /// No description provided for @selectOpenApiFile.
  ///
  /// In en, this message translates to:
  /// **'Select OpenAPI JSON file'**
  String get selectOpenApiFile;

  /// No description provided for @openApiFileLoaded.
  ///
  /// In en, this message translates to:
  /// **'Loaded {name}'**
  String openApiFileLoaded(String name);

  /// No description provided for @openApiFileReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the selected OpenAPI file.'**
  String get openApiFileReadFailed;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @method.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get method;

  /// No description provided for @path.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get path;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @when.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get when;

  /// No description provided for @openExecutionSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Open execution snapshot'**
  String get openExecutionSnapshot;

  /// No description provided for @legacyExecutionNoSnapshot.
  ///
  /// In en, this message translates to:
  /// **'This legacy execution has no stored snapshot'**
  String get legacyExecutionNoSnapshot;

  /// No description provided for @collectionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} collections'**
  String collectionCount(int count);

  /// No description provided for @deleteCollectionConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} and its {count, plural, =0{requests} =1{1 request} other{{count} requests}}?'**
  String deleteCollectionConfirmation(String name, int count);

  /// No description provided for @deleteFolderConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} and its {count, plural, =0{requests} =1{1 request} other{{count} requests}}?'**
  String deleteFolderConfirmation(String name, int count);

  /// No description provided for @deleteRequestConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteRequestConfirmation(String name);

  /// No description provided for @deleteWithUnsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'{description} {count, plural, =1{1 request has} other{{count} requests have}} unsaved changes.'**
  String deleteWithUnsavedChanges(String description, int count);

  /// No description provided for @collectionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Collection deleted.'**
  String get collectionDeleted;

  /// No description provided for @folderDeleted.
  ///
  /// In en, this message translates to:
  /// **'Folder deleted.'**
  String get folderDeleted;

  /// No description provided for @requestDeleted.
  ///
  /// In en, this message translates to:
  /// **'Request deleted.'**
  String get requestDeleted;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed.'**
  String get importFailed;

  /// No description provided for @openApiJsonExample.
  ///
  /// In en, this message translates to:
  /// **'\'{ \"openapi\": \"3.0.0\" }\''**
  String get openApiJsonExample;

  /// No description provided for @validOpenApiJsonRequired.
  ///
  /// In en, this message translates to:
  /// **'Paste valid OpenAPI JSON.'**
  String get validOpenApiJsonRequired;

  /// No description provided for @openApiRequestsImported.
  ///
  /// In en, this message translates to:
  /// **'{count} OpenAPI requests imported into {name}.'**
  String openApiRequestsImported(int count, String name);

  /// No description provided for @openApiExportedTo.
  ///
  /// In en, this message translates to:
  /// **'OpenAPI exported to {path}.'**
  String openApiExportedTo(String path);

  /// No description provided for @openApiExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export OpenAPI: {error}'**
  String openApiExportFailed(String error);

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @renameCollection.
  ///
  /// In en, this message translates to:
  /// **'Rename collection'**
  String get renameCollection;

  /// No description provided for @renameFolder.
  ///
  /// In en, this message translates to:
  /// **'Rename folder'**
  String get renameFolder;

  /// No description provided for @renameRequest.
  ///
  /// In en, this message translates to:
  /// **'Rename request'**
  String get renameRequest;

  /// No description provided for @deleteCollection.
  ///
  /// In en, this message translates to:
  /// **'Delete collection'**
  String get deleteCollection;

  /// No description provided for @deleteFolder.
  ///
  /// In en, this message translates to:
  /// **'Delete folder'**
  String get deleteFolder;

  /// No description provided for @deleteRequest.
  ///
  /// In en, this message translates to:
  /// **'Delete request'**
  String get deleteRequest;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @unsavedRequestChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved request changes'**
  String get unsavedRequestChanges;

  /// No description provided for @discardAndDelete.
  ///
  /// In en, this message translates to:
  /// **'Discard and delete'**
  String get discardAndDelete;

  /// No description provided for @saveAndDelete.
  ///
  /// In en, this message translates to:
  /// **'Save and delete'**
  String get saveAndDelete;

  /// No description provided for @webSocketProtocol.
  ///
  /// In en, this message translates to:
  /// **'WebSocket protocol'**
  String get webSocketProtocol;

  /// No description provided for @webSocketProtocolHint.
  ///
  /// In en, this message translates to:
  /// **'Optional subprotocols sent during the handshake.'**
  String get webSocketProtocolHint;

  /// No description provided for @subprotocols.
  ///
  /// In en, this message translates to:
  /// **'Subprotocols'**
  String get subprotocols;

  /// No description provided for @protobufDescriptor.
  ///
  /// In en, this message translates to:
  /// **'Protobuf descriptor'**
  String get protobufDescriptor;

  /// No description provided for @descriptorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Descriptor file is unavailable. Import it again to recover this request.'**
  String get descriptorUnavailable;

  /// No description provided for @noDescriptorSelected.
  ///
  /// In en, this message translates to:
  /// **'No descriptor set selected'**
  String get noDescriptorSelected;

  /// No description provided for @messageType.
  ///
  /// In en, this message translates to:
  /// **'Message type'**
  String get messageType;

  /// No description provided for @addField.
  ///
  /// In en, this message translates to:
  /// **'Add field'**
  String get addField;

  /// No description provided for @addRow.
  ///
  /// In en, this message translates to:
  /// **'Add row'**
  String get addRow;

  /// No description provided for @key.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get key;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @removeRow.
  ///
  /// In en, this message translates to:
  /// **'Remove row'**
  String get removeRow;

  /// No description provided for @changeBodyContentType.
  ///
  /// In en, this message translates to:
  /// **'Change body content type'**
  String get changeBodyContentType;

  /// No description provided for @noContentType.
  ///
  /// In en, this message translates to:
  /// **'No content type'**
  String get noContentType;

  /// No description provided for @requestBodyHint.
  ///
  /// In en, this message translates to:
  /// **'// Request body'**
  String get requestBodyHint;

  /// No description provided for @requestTabParams.
  ///
  /// In en, this message translates to:
  /// **'Params'**
  String get requestTabParams;

  /// No description provided for @requestTabHeaders.
  ///
  /// In en, this message translates to:
  /// **'Headers'**
  String get requestTabHeaders;

  /// No description provided for @requestTabAuth.
  ///
  /// In en, this message translates to:
  /// **'Auth'**
  String get requestTabAuth;

  /// No description provided for @requestTabBody.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get requestTabBody;

  /// No description provided for @requestTabProtocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get requestTabProtocol;

  /// No description provided for @subprotocolsHint.
  ///
  /// In en, this message translates to:
  /// **'graphql-transport-ws, events.v1'**
  String get subprotocolsHint;

  /// No description provided for @sendRequestWithShortcut.
  ///
  /// In en, this message translates to:
  /// **'Send request ({shortcut})'**
  String sendRequestWithShortcut(String shortcut);

  /// No description provided for @fieldEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable field'**
  String get fieldEnabled;

  /// No description provided for @fieldDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disable field'**
  String get fieldDisabled;

  /// No description provided for @fileEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable file'**
  String get fileEnabled;

  /// No description provided for @fileDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disable file'**
  String get fileDisabled;

  /// No description provided for @removeSecretProtection.
  ///
  /// In en, this message translates to:
  /// **'Remove secret protection'**
  String get removeSecretProtection;

  /// No description provided for @selectedFilesUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Some selected files could not be read.'**
  String get selectedFilesUnreadable;

  /// No description provided for @addFormField.
  ///
  /// In en, this message translates to:
  /// **'Add form field'**
  String get addFormField;

  /// No description provided for @removeFile.
  ///
  /// In en, this message translates to:
  /// **'Remove file'**
  String get removeFile;

  /// No description provided for @removeFormField.
  ///
  /// In en, this message translates to:
  /// **'Remove form field'**
  String get removeFormField;

  /// No description provided for @batchField.
  ///
  /// In en, this message translates to:
  /// **'BATCH FIELD'**
  String get batchField;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Field name'**
  String get fieldName;

  /// No description provided for @field.
  ///
  /// In en, this message translates to:
  /// **'Field'**
  String get field;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get enabled;

  /// No description provided for @activeFieldCount.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String activeFieldCount(int count);

  /// No description provided for @disableRow.
  ///
  /// In en, this message translates to:
  /// **'Disable row'**
  String get disableRow;

  /// No description provided for @enableRow.
  ///
  /// In en, this message translates to:
  /// **'Enable row'**
  String get enableRow;

  /// No description provided for @hideValue.
  ///
  /// In en, this message translates to:
  /// **'Hide value'**
  String get hideValue;

  /// No description provided for @revealValue.
  ///
  /// In en, this message translates to:
  /// **'Reveal value'**
  String get revealValue;

  /// No description provided for @markAsSecret.
  ///
  /// In en, this message translates to:
  /// **'Mark as secret'**
  String get markAsSecret;

  /// No description provided for @chooseFilesDescription.
  ///
  /// In en, this message translates to:
  /// **'Select one or more files to send with this request.'**
  String get chooseFilesDescription;

  /// No description provided for @authorizationAppliedAsHeader.
  ///
  /// In en, this message translates to:
  /// **'Independent authentication settings'**
  String get authorizationAppliedAsHeader;

  /// No description provided for @customAuthorizationConfigured.
  ///
  /// In en, this message translates to:
  /// **'A custom Authorization header is configured for this request.'**
  String get customAuthorizationConfigured;

  /// No description provided for @customAuthorizationHeader.
  ///
  /// In en, this message translates to:
  /// **'Custom Authorization header'**
  String get customAuthorizationHeader;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @token.
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get token;

  /// No description provided for @bearerTokenStored.
  ///
  /// In en, this message translates to:
  /// **'Authorization is generated only when this request runs.'**
  String get bearerTokenStored;

  /// No description provided for @noAuthorizationHeader.
  ///
  /// In en, this message translates to:
  /// **'This request uses no authentication.'**
  String get noAuthorizationHeader;

  /// No description provided for @webSocketUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'WebSocket URL must use ws:// or wss://.'**
  String get webSocketUrlRequired;

  /// No description provided for @originalRequestDeletedNotice.
  ///
  /// In en, this message translates to:
  /// **'The original request was deleted.'**
  String get originalRequestDeletedNotice;

  /// No description provided for @mockServerStarted.
  ///
  /// In en, this message translates to:
  /// **'Quick Mock started.'**
  String get mockServerStarted;

  /// No description provided for @mockServerStopped.
  ///
  /// In en, this message translates to:
  /// **'Quick Mock stopped.'**
  String get mockServerStopped;

  /// No description provided for @mockServerStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start Quick Mock. Retry.'**
  String get mockServerStartFailed;

  /// No description provided for @mockServerStopFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not stop Quick Mock. Retry.'**
  String get mockServerStopFailed;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @chooseFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose files'**
  String get chooseFiles;

  /// No description provided for @formFields.
  ///
  /// In en, this message translates to:
  /// **'Form fields'**
  String get formFields;

  /// No description provided for @browse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get browse;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @bearerToken.
  ///
  /// In en, this message translates to:
  /// **'Bearer token'**
  String get bearerToken;

  /// No description provided for @noAuth.
  ///
  /// In en, this message translates to:
  /// **'No auth'**
  String get noAuth;

  /// No description provided for @pasteBearerToken.
  ///
  /// In en, this message translates to:
  /// **'Paste a bearer token'**
  String get pasteBearerToken;

  /// No description provided for @earlierMessagesOmitted.
  ///
  /// In en, this message translates to:
  /// **'{count} earlier messages omitted to protect memory.'**
  String earlierMessagesOmitted(int count);

  /// No description provided for @webSocketInbound.
  ///
  /// In en, this message translates to:
  /// **'IN'**
  String get webSocketInbound;

  /// No description provided for @webSocketOutbound.
  ///
  /// In en, this message translates to:
  /// **'OUT'**
  String get webSocketOutbound;

  /// No description provided for @webSocketSystem.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM'**
  String get webSocketSystem;

  /// No description provided for @webSocketTextFrame.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get webSocketTextFrame;

  /// No description provided for @webSocketBinaryFrame.
  ///
  /// In en, this message translates to:
  /// **'Binary'**
  String get webSocketBinaryFrame;

  /// No description provided for @webSocketCloseFrame.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get webSocketCloseFrame;

  /// No description provided for @webSocketErrorFrame.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get webSocketErrorFrame;

  /// No description provided for @webSocketMessageSemantics.
  ///
  /// In en, this message translates to:
  /// **'{direction} {kind} message, {bytes} bytes'**
  String webSocketMessageSemantics(String direction, String kind, int bytes);

  /// No description provided for @byteCount.
  ///
  /// In en, this message translates to:
  /// **'{count} B'**
  String byteCount(int count);

  /// No description provided for @webSocketConnectionTimedOut.
  ///
  /// In en, this message translates to:
  /// **'WebSocket connection timed out.'**
  String get webSocketConnectionTimedOut;

  /// No description provided for @webSocketMessageFormat.
  ///
  /// In en, this message translates to:
  /// **'Choose message format'**
  String get webSocketMessageFormat;

  /// No description provided for @webSocketTextFrameHeading.
  ///
  /// In en, this message translates to:
  /// **'TEXT FRAME'**
  String get webSocketTextFrameHeading;

  /// No description provided for @webSocketBinaryFrameHeading.
  ///
  /// In en, this message translates to:
  /// **'BINARY FRAME'**
  String get webSocketBinaryFrameHeading;

  /// No description provided for @pasteSerializedMessageBase64.
  ///
  /// In en, this message translates to:
  /// **'Paste Base64 for serialized {format} bytes.'**
  String pasteSerializedMessageBase64(String format);

  /// No description provided for @grpcResponseTitle.
  ///
  /// In en, this message translates to:
  /// **'gRPC response'**
  String get grpcResponseTitle;

  /// No description provided for @cancelGrpcCall.
  ///
  /// In en, this message translates to:
  /// **'Cancel gRPC call'**
  String get cancelGrpcCall;

  /// No description provided for @earlierGrpcEventsOmitted.
  ///
  /// In en, this message translates to:
  /// **'{count} earlier events omitted'**
  String earlierGrpcEventsOmitted(int count);

  /// No description provided for @awaitingGrpcResponse.
  ///
  /// In en, this message translates to:
  /// **'Awaiting gRPC response'**
  String get awaitingGrpcResponse;

  /// No description provided for @sendActiveRequestRequired.
  ///
  /// In en, this message translates to:
  /// **'Send is available when an active request is open.'**
  String get sendActiveRequestRequired;

  /// No description provided for @requestAlreadySending.
  ///
  /// In en, this message translates to:
  /// **'The active request is already sending.'**
  String get requestAlreadySending;

  /// No description provided for @enterRequestUrlBeforeSending.
  ///
  /// In en, this message translates to:
  /// **'Enter a request URL before sending.'**
  String get enterRequestUrlBeforeSending;

  /// No description provided for @selectProtobufSchemaBeforeSending.
  ///
  /// In en, this message translates to:
  /// **'Select a Protobuf schema and message type before sending.'**
  String get selectProtobufSchemaBeforeSending;

  /// No description provided for @importProtobufDescriptorBeforeSending.
  ///
  /// In en, this message translates to:
  /// **'Import a valid Protobuf descriptor set before sending.'**
  String get importProtobufDescriptorBeforeSending;

  /// No description provided for @enterJsonMessageBeforeFormatting.
  ///
  /// In en, this message translates to:
  /// **'Enter a JSON message before formatting.'**
  String get enterJsonMessageBeforeFormatting;

  /// No description provided for @messageNotValidJson.
  ///
  /// In en, this message translates to:
  /// **'The message is not valid JSON.'**
  String get messageNotValidJson;

  /// No description provided for @binaryMessagesRequireBase64.
  ///
  /// In en, this message translates to:
  /// **'Binary messages must use valid Base64.'**
  String get binaryMessagesRequireBase64;

  /// No description provided for @enterJsonRequestBodyBeforeFormatting.
  ///
  /// In en, this message translates to:
  /// **'Enter a JSON request body before formatting.'**
  String get enterJsonRequestBodyBeforeFormatting;

  /// No description provided for @requestBodyNotValidJson.
  ///
  /// In en, this message translates to:
  /// **'The request body is not valid JSON.'**
  String get requestBodyNotValidJson;

  /// No description provided for @encodesToBytes.
  ///
  /// In en, this message translates to:
  /// **'Encodes to {count} bytes'**
  String encodesToBytes(int count);

  /// No description provided for @sendRequestBeforeMockDraft.
  ///
  /// In en, this message translates to:
  /// **'Send a request before creating a Quick Mock.'**
  String get sendRequestBeforeMockDraft;

  /// No description provided for @sendRequestBeforeDocumentation.
  ///
  /// In en, this message translates to:
  /// **'Send a request before creating documentation.'**
  String get sendRequestBeforeDocumentation;

  /// No description provided for @createMockDraftBeforeStartingServer.
  ///
  /// In en, this message translates to:
  /// **'Create a Quick Mock before starting it.'**
  String get createMockDraftBeforeStartingServer;

  /// No description provided for @couldNotSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not send message: {error}'**
  String couldNotSendMessage(String error);

  /// No description provided for @connectionClosed.
  ///
  /// In en, this message translates to:
  /// **'Connection closed.'**
  String get connectionClosed;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed.'**
  String get connectionFailed;

  /// No description provided for @couldNotImportProto.
  ///
  /// In en, this message translates to:
  /// **'Could not import proto source: {error}'**
  String couldNotImportProto(String error);

  /// No description provided for @couldNotImportDescriptorSet.
  ///
  /// In en, this message translates to:
  /// **'Could not import descriptor set: {error}'**
  String couldNotImportDescriptorSet(String error);

  /// No description provided for @oneofOnlyOneField.
  ///
  /// In en, this message translates to:
  /// **'Only one field may be set for oneof {name}.'**
  String oneofOnlyOneField(String name);

  /// No description provided for @invalidEnumValueForField.
  ///
  /// In en, this message translates to:
  /// **'Invalid enum value for {field}.'**
  String invalidEnumValueForField(String field);

  /// No description provided for @unexpectedWireTypeForField.
  ///
  /// In en, this message translates to:
  /// **'Unexpected wire type for {path}.'**
  String unexpectedWireTypeForField(String path);

  /// No description provided for @unsupportedProtobufFieldType.
  ///
  /// In en, this message translates to:
  /// **'Unsupported Protobuf field type for {path}.'**
  String unsupportedProtobufFieldType(String path);

  /// No description provided for @pasteOpenApi3JsonRequired.
  ///
  /// In en, this message translates to:
  /// **'Paste an OpenAPI 3.x JSON document with a paths object.'**
  String get pasteOpenApi3JsonRequired;

  /// No description provided for @noSupportedHttpOperations.
  ///
  /// In en, this message translates to:
  /// **'No supported HTTP operations found.'**
  String get noSupportedHttpOperations;

  /// No description provided for @unsupportedWebSocketFrame.
  ///
  /// In en, this message translates to:
  /// **'Unsupported WebSocket frame.'**
  String get unsupportedWebSocketFrame;

  /// No description provided for @protobufJsonMustBeObject.
  ///
  /// In en, this message translates to:
  /// **'Protobuf JSON message must be an object.'**
  String get protobufJsonMustBeObject;

  /// No description provided for @unknownProtobufMessageType.
  ///
  /// In en, this message translates to:
  /// **'Unknown Protobuf message type: {name}'**
  String unknownProtobufMessageType(String name);

  /// No description provided for @unknownProtobufField.
  ///
  /// In en, this message translates to:
  /// **'Unknown field: {path}'**
  String unknownProtobufField(String path);

  /// No description provided for @unexpectedEndOfProtobufData.
  ///
  /// In en, this message translates to:
  /// **'Unexpected end of Protobuf data.'**
  String get unexpectedEndOfProtobufData;

  /// No description provided for @invalidProtobufLength.
  ///
  /// In en, this message translates to:
  /// **'Invalid Protobuf length.'**
  String get invalidProtobufLength;

  /// No description provided for @unsupportedProtobufWireType.
  ///
  /// In en, this message translates to:
  /// **'Unsupported Protobuf wire type.'**
  String get unsupportedProtobufWireType;

  /// No description provided for @requestTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Request timed out after 20 seconds.'**
  String get requestTimedOut;

  /// No description provided for @requestCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled.'**
  String get requestCancelled;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
