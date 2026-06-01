Pod::Spec.new do |s|
  s.name             = 'VeltoKit'
  s.version          = '0.1.0'
  s.summary          = 'BLE motion bytes → GameInput for iOS games'
  s.description      = <<-DESC
    VeltoKit maps reverse-engineered BLE cap IMU + button packets into a unified
    GameInput struct each frame. Swift, iOS 16+, no UI and no CoreBluetooth in the core library.
  DESC
  s.homepage         = 'https://github.com/przemyslawsikora/veltokit'
  s.license          = { type: 'MIT', file: 'LICENSE' }
  s.author           = { 'Koderteam' => 'https://github.com/przemyslawsikora' }
  s.source           = { git: 'https://github.com/przemyslawsikora/veltokit.git', tag: s.version.to_s }
  s.platform         = :ios, '16.0'
  s.swift_version    = '5.9'
  s.source_files     = 'VeltoKit/**/*.swift'
  s.frameworks       = 'Foundation', 'CoreBluetooth'
  s.requires_arc     = true
end
