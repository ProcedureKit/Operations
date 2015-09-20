Pod::Spec.new do |s|
  s.name              = "Operations"
  s.version           = "2.0.2"
  s.summary           = "Powerful NSOperation subclasses in Swift."
  s.description       = <<-DESC
  
A Swift 1.2 framework inspired by Apple's WWDC 2015
session Advanced NSOperations: https://developer.apple.com/videos/wwdc/2015/?id=226

                       DESC
  s.homepage          = "https://github.com/danthorpe/Operations"
  s.license           = 'MIT'
  s.author            = { "Daniel Thorpe" => "@danthorpe" }
  s.source            = { :git => "https://github.com/danthorpe/Operations.git", :tag => s.version.to_s }
  s.module_name       = 'Operations'
  s.social_media_url  = 'https://twitter.com/danthorpe'
  s.requires_arc      = true
  s.default_subspec   = 'Base'
  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"

  s.subspec 'Base' do |ss|
    ss.source_files      = 'Operations/**/*.{swift,m,h}'
    ss.exclude_files     = 'Operations/Extras/**/*.{swift,m,h}'
    ss.osx.exclude_files = 'Operations/**/*{RemoteNotification,UserConfirmation,AddressBook,LocationCondition,BackgroundObserver,NetworkObserver,AlertOperation,LocationOperation}*'
  end

  s.subspec '+AddressBook' do |ss|
    ss.dependency 'Operations/Base'    
    ss.source_files   = 'Operations/AddressBook/**/*.{swift,m,h}'
    ss.osx.exclude_files = 'Operations/AddressBook/**'
  end

  s.subspec '+Extras' do |ss|
    ss.dependency 'Operations/+AddressBook'
  end
end

