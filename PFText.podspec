Pod::Spec.new do |s|

  s.name         = "PFText"
  s.version      = "2.1.0"
  s.summary      = "富文本,coretext"
  s.description  = <<-DESC
                   富文本,异步绘制,可自定义规则,支持本地图片,网络图片,gif,粘贴板
                   DESC
  s.homepage     = "https://github.com/LongPF/PFText"
  s.platform     = :ios, '7.0'
  s.license      = "MIT"
  s.author             = { "longpengfei" => "466142249@qq.com" }
  s.source       = { :git => "https://github.com/LongPF/PFText.git", :tag => s.version }
  s.source_files  = "PFText/**/*.{h,m}"
  s.public_header_files = "PFText/**/*.{h}"
  s.frameworks = 'UIKit', 'CoreText', 'Foundation'
  s.requires_arc = true

end
