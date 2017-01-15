#
# Be sure to run `pod lib lint Carpaccio.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Carpaccio'
  s.version          = '0.0.5'
  s.summary          = 'A pure Swift library for decoding image data and EXIF metadata (including RAW files).'

  s.description      = <<-DESC
Carpaccio is a Swift library that allows decoding image data from file formats supported by CoreImage (including all the various RAW file formats supported by CoreImage). It is built for efficient use of multiple CPU cores.
                       DESC

  s.homepage         = 'https://github.com/mz2/Carpaccio'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Matias Piipari' => 'matias.piipari@gmail.com' }
  s.source           = { :git => 'https://gitlab.com/sashimiapp-public/Carpaccio.git', :tag => '0.0.5' }

  s.social_media_url = 'https://twitter.com/mz2'
  
  s.module_name      = 'Carpaccio'
  
  s.ios.framework = 'UIKit'
  s.osx.framework = 'AppKit'
  
  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.10'

  s.ios.source_files = 'Carpaccio/*.swift', 'Carpaccio/iOS/*.swift'
  s.osx.source_files = 'Carpaccio/*.swift', 'Carpaccio/macOS/*.swift'
end
