//
//  PFTextView.h
//  PFTextView
//
//  Created by 龙鹏飞 on 2016/11/10.
//  Copyright © 2016年 https://github.com/LongPF/PFText. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PFTextRun.h"

@class PFTextView;

@protocol PFTextViewDelegate <NSObject>

@optional
- (void)textView:(PFTextView *)view touchBeginRun:(PFTextRun *)run;
- (void)textView:(PFTextView *)view touchEndRun:(PFTextRun *)run;
- (void)textView:(PFTextView *)view touchCanceledRun:(PFTextRun *)run;

@end

@interface PFTextView : UIView

@property (nonatomic, copy) NSString *text;

@property (nonatomic, strong) UIColor *textColor;

@property (nonatomic, strong) UIFont *font;

/**
 设置文本的样式,可以根据需要自定义 PFRichTextRun 添加到数组中. 例如:
 *  PFRichTextAtRun *run = [PFRichTextAtRun new];
 *  run.font = ..;
 *  run.textColor = ..;
 *  richTextView.settingRuns = @[run];
 *  这里不必设置run的range等属性...只需要设置@的显示的 *样式*
 *  用户可根据自己需要自定义PFRichTextRun并添加到settingRuns,来实现定制效果
 */
@property (nonatomic, strong) NSArray <PFTextRun *> *settingRuns;

/**
 回调触摸时间的代理
 */
@property (nonatomic, assign) id<PFTextViewDelegate>delegate;

/**
 行数,设置为0则不限制行数, 默认为0
 */
@property (nonatomic, assign) NSInteger numberOfLines;

/**
 换行模式
 */
@property (nonatomic, assign) NSLineBreakMode lineBreakMode;

/**
 对齐方式
 */
@property (nonatomic, assign)NSTextAlignment textAlignment;

/**
 行间距,默认为2
 */
@property (nonatomic, assign) CGFloat lineSpacing;

/**
 段落前缩进
 */
@property (nonatomic, assign) CGFloat paragraphHeadIndent;

/**
 段落尾缩进,值应该为负值
 */
@property (nonatomic, assign) CGFloat paragraphTailIndent;

/**
 首行缩进
 */
@property (nonatomic, assign) CGFloat firstLineHeadIndent;

/**
 获取一个最适合的高度,不会改变自身的高度
 
 @param width 绘制文本的宽度,如果传0,则取 width = self.bounds.size.width
 
 @return 返回一个适合的高度
 */
- (CGFloat)heightThatFit:(CGFloat)width;


/**
 该方法会调用heightThatFit:,传入width = self.bounds.size.width, 该方法会改变自身的高度
 */
- (void)heightToFit;

@end