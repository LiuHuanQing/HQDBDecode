
Pod::Spec.new do |s|
  s.name         = "HQDBDecode"
  s.version      = "1.0.3"
  s.summary      = "数据库对象映射模型"

  s.description  = <<-DESC
  数据库对象映射模型.
                   DESC

  s.homepage     = "https://github.com/LiuHuanQing/HQDBDecode"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "刘欢庆" => "liu-lhq@163.com" }
  s.platform     = :ios, "8.0"
  s.source       = { :git => "https://github.com/LiuHuanQing/HQDBDecode.git", :tag => s.version.to_s }
  s.source_files  = "Classes", "Classes/**/*.{h,m}"
  s.exclude_files = "Exclude"
  s.frameworks = "FMDB", "YYModel"
  s.dependency "FMDB"
  s.dependency "YYModel", "~> 1.0.4"


  s.subspec 'Secret' do |ss| 
    ss.ios.deployment_target = '8.0'
    ss.source_files  = "Classes", "Classes/**/*.{h,m}"
    ss.dependency 'FMDB/SQLCipher'
    ss.dependency "YYModel", "~> 1.0.4"
    end

end
