#!/usr/bin/env ruby
# Adds a XCUITest target to the WelcomTalk Xcode project using the xcodeproj gem.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../WelcomTalk.xcodeproj', __dir__)
TEST_TARGET_NAME = 'WelcomTalkUITests'
APP_TARGET_NAME  = 'WelcomTalk'
BUNDLE_ID        = 'com.waelio.WelcomTalkUITests'
SWIFT_VERSION    = '5.0'
TEAM_ID          = '5CY5WTPYKZ'

project = Xcodeproj::Project.open(PROJECT_PATH)

# Bail out if the target already exists
if project.targets.map(&:name).include?(TEST_TARGET_NAME)
  puts "Target '#{TEST_TARGET_NAME}' already exists – nothing to do."
  exit 0
end

app_target = project.targets.find { |t| t.name == APP_TARGET_NAME }
abort "Could not find app target '#{APP_TARGET_NAME}'" unless app_target

# ---- Create UITest target -----------------------------------------------
ui_test_target = project.new_target(
  :ui_testing_bundle,
  TEST_TARGET_NAME,
  :ios,
  nil,   # deployment target – inherits from project
  project.frameworks_group,
  :swift
)

# ---- Wire the test-host dependency to the app ---------------------------
container_proxy = project.new(Xcodeproj::Project::Object::PBXContainerItemProxy)
container_proxy.container_portal = project.root_object.uuid
container_proxy.proxy_type       = '1'
container_proxy.remote_global_id_string = app_target.uuid
container_proxy.remote_info      = APP_TARGET_NAME

dep = project.new(Xcodeproj::Project::Object::PBXTargetDependency)
dep.target      = app_target
dep.target_proxy = container_proxy
ui_test_target.dependencies << dep

# ---- Build settings for both Debug and Release --------------------------
[ui_test_target.build_configuration_list['Debug'],
 ui_test_target.build_configuration_list['Release']].each do |cfg|
  next unless cfg
  cfg.build_settings['BUNDLE_LOADER']              = '$(TEST_HOST)'
  cfg.build_settings['TEST_HOST']                  =
    '$(BUILT_PRODUCTS_DIR)/WelcomTalk.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/WelcomTalk'
  cfg.build_settings['PRODUCT_BUNDLE_IDENTIFIER']  = BUNDLE_ID
  cfg.build_settings['SWIFT_VERSION']              = SWIFT_VERSION
  cfg.build_settings['TARGETED_DEVICE_FAMILY']     = '1,2'
  cfg.build_settings['CODE_SIGN_STYLE']            = 'Automatic'
  cfg.build_settings['DEVELOPMENT_TEAM']           = TEAM_ID
  cfg.build_settings['GENERATE_INFOPLIST_FILE']    = 'YES'
  cfg.build_settings['LD_RUNPATH_SEARCH_PATHS']    = ['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks']
  cfg.build_settings['SWIFT_DEFAULT_ACTOR_ISOLATION'] = 'MainActor'
  cfg.build_settings['SWIFT_APPROACHABLE_CONCURRENCY'] = 'YES'
end

# ---- Add the test source files to a group --------------------------------
tests_group = project.main_group.new_group(TEST_TARGET_NAME, TEST_TARGET_NAME)

test_files = [
  "#{TEST_TARGET_NAME}/WelcomTalkUITests.swift",
  "#{TEST_TARGET_NAME}/CreateSessionUITests.swift",
  "#{TEST_TARGET_NAME}/JoinSessionUITests.swift",
  "#{TEST_TARGET_NAME}/DemoSessionUITests.swift",
]

test_files.each do |rel_path|
  file_ref = tests_group.new_file(File.basename(rel_path))
  ui_test_target.source_build_phase.add_file_reference(file_ref)
end

# ---- Register target attributes (required for signing) ------------------
project.root_object.attributes['TargetAttributes'] ||= {}
project.root_object.attributes['TargetAttributes'][ui_test_target.uuid] = {
  'CreatedOnToolsVersion' => '26.3',
  'TestTargetID'          => app_target.uuid,
}

project.save
puts "✅  Target '#{TEST_TARGET_NAME}' added successfully."
