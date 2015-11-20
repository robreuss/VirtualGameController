#
# Be sure to run `pod lib lint VirtualGameController.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "VirtualGameController"
  s.version          = "0.0.3"
  s.summary          = "Feature-rich game controller framework for iOS, tvOS, OS X and watchOS in Swift 2.1."
  s.description      = <<-DESC


                       DESC

  s.homepage         = "https://github.com/robreuss/VirtualGameController"
  s.screenshots     = "https://camo.githubusercontent.com/1b07892c002d93ac885cee5d02310eb4b5fa5dd8/687474703a2f2f726f6272657573732e73717561726573706163652e636f6d2f73746f726167652f7065726970686572616c322e706e67", "https://camo.githubusercontent.com/45cd1c7be25e9d6195e2e4872ade1c2ce55106ea/687474703a2f2f726f6272657573732e73717561726573706163652e636f6d2f73746f726167652f63656e7472616c322e706e67", "https://camo.githubusercontent.com/82b44db527ec7cddbf7bd924e3ca46314345021e/687474703a2f2f726f6272657573732e73717561726573706163652e636f6d2f73746f726167652f7065726970686572616c5f63656e7472616c5f73656c6563746f72322e706e67"
  s.license          = 'MIT'
  s.author           = { "Rob Reuss" => "virtualgamecontroller@gmail.com" }
  s.source           = { :git => "https://github.com/robreuss/VirtualGameController.git", :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/robreuss'

  s.platform     = :ios, '8.0'
  s.osx.deployment_target = '10.9'
  s.tvos.deployment_target = '9.0'
  s.ios.deployment_target = '9.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
