Pod::Spec.new do |spec|
  spec.name             = 'rhs_player'
  spec.version          = '0.6.0'
  spec.summary          = 'Native network video player for Flutter.'
  spec.description      = <<-DESC
Native network video player using ExoPlayer on Android and AVPlayer on iOS.
                       DESC
  spec.homepage         = 'https://github.com/unger1984/rhs_player'
  spec.license          = { :type => 'MIT', :file => '../LICENSE' }
  spec.author           = { 'rhs_player contributors' => 'unger1984@users.noreply.github.com' }
  spec.source           = {
    :git => 'https://github.com/unger1984/rhs_player.git',
    :tag => spec.version.to_s
  }
  spec.source_files     = 'rhs_player/Sources/rhs_player/**/*.swift'
  spec.resource_bundles = {
    'rhs_player_privacy' => ['rhs_player/Sources/rhs_player/PrivacyInfo.xcprivacy']
  }
  spec.dependency 'Flutter'
  spec.platform = :ios, '12.0'
  spec.frameworks = 'AVFoundation', 'AVKit', 'MediaPlayer'
  spec.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  spec.swift_version = '5.0'
end
