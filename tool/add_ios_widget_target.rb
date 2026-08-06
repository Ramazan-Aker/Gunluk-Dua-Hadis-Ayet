#!/usr/bin/env ruby
# frozen_string_literal: true

# Codemagic üzerinde DailyVerseWidget App Extension hedefini idempotent olarak
# Runner.xcodeproj içine ekler. Mac/Xcode arayüzüne ihtiyaç bırakmaz.

require 'xcodeproj'

project_path = File.expand_path('../ios/Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

target_name = 'DailyVerseWidget'
bundle_id = 'com.tahram.gunlukduahadis.DailyVerseWidget'
deployment_target = '14.0'
team_id = ENV.fetch('APPLE_TEAM_ID', 'F7TL9YHWSA')

runner = project.targets.find { |target| target.name == 'Runner' }
abort 'Runner target bulunamadı.' unless runner

widget = project.targets.find { |target| target.name == target_name }
widget ||= project.new_target(
  :app_extension,
  target_name,
  :ios,
  deployment_target
)

widget_group = project.main_group.find_subpath(target_name, true)
widget_group.set_source_tree('<group>')
widget_group.path = target_name

def find_or_add_file(group, path)
  group.files.find { |file| file.path == path } || group.new_file(path)
end

swift_file = find_or_add_file(widget_group, 'DailyVerseWidget.swift')
find_or_add_file(widget_group, 'Info.plist')
find_or_add_file(widget_group, 'DailyVerseWidget.entitlements')

unless widget.source_build_phase.files_references.include?(swift_file)
  widget.source_build_phase.add_file_reference(swift_file, true)
end

pubspec_path = File.expand_path('../pubspec.yaml', __dir__)
version_line = File.readlines(pubspec_path).find { |line| line.start_with?('version:') }
full_version = version_line&.split(':', 2)&.last&.strip || '1.0.0+1'
marketing_version, build_number = full_version.split('+', 2)
build_number ||= '1'

widget.build_configurations.each do |configuration|
  settings = configuration.build_settings
  settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  settings['CODE_SIGN_ENTITLEMENTS'] = 'DailyVerseWidget/DailyVerseWidget.entitlements'
  settings['CODE_SIGN_STYLE'] = 'Automatic'
  settings['CURRENT_PROJECT_VERSION'] = build_number
  settings['DEVELOPMENT_TEAM'] = team_id
  settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  settings['INFOPLIST_FILE'] = 'DailyVerseWidget/Info.plist'
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = deployment_target
  settings['MARKETING_VERSION'] = marketing_version
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
  settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  settings['SKIP_INSTALL'] = 'YES'
  settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  settings['SWIFT_VERSION'] = '5.0'
  settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  settings['VERSIONING_SYSTEM'] = 'apple-generic'
end

runner.build_configurations.each do |configuration|
  configuration.build_settings['CODE_SIGN_ENTITLEMENTS'] =
    'Runner/Runner.entitlements'
end

unless runner.dependencies.any? { |dependency| dependency.target == widget }
  runner.add_dependency(widget)
end

embed_phase = runner.copy_files_build_phases.find do |phase|
  phase.name == 'Embed Foundation Extensions'
end
embed_phase ||= runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed_phase.dst_subfolder_spec = '13'

unless embed_phase.files_references.include?(widget.product_reference)
  build_file = embed_phase.add_file_reference(widget.product_reference, true)
  build_file.settings = {
    'ATTRIBUTES' => %w[CodeSignOnCopy RemoveHeadersOnCopy]
  }
end

# Flutter'ın Thin Binary adımından önce uzantıyı gömerek Xcode build-cycle
# hatasını engelle.
thin_phase = runner.shell_script_build_phases.find { |phase| phase.name == 'Thin Binary' }
if thin_phase
  runner.build_phases.delete(embed_phase)
  thin_index = runner.build_phases.index(thin_phase) || runner.build_phases.length
  runner.build_phases.insert(thin_index, embed_phase)
end

project.save
puts "#{target_name} target hazırlandı (#{bundle_id})."
