//
//  PFTextRun.h
//  PFTextView
//
//  Created by 龙鹏飞 on 2016/11/10.
//  Copyright © 2016年 https://github.com/LongPF/PFText. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>
#import <UIKit/UIKit.h>

/**
 *  @brief 子类需要重写configRun: (需要调用 super),  parseText: textRunsArray: (不需要调用super)
 
 */

@interface PFTextRun : NSObject

/**
 正则或其他方式筛选出来的文本
 */
@property (nonatomic, copy) NSString *text;

/**
 颜色
 */
@property (nonatomic, strong) UIColor *textColor;

/**
 字体
 */
@property (nonatomic, strong) UIFont *font;

/**
 *  @brief range
 */
@property (nonatomic) NSRange range;

/**
 @brief 是否响应触摸事件
 */
@property (nonatomic, assign) BOOL isResponseTouch;

/**
 是否自己绘制自己,默认是NO,如果设置为YES 则需要重写 drawRunWithRect:
 */
@property (nonatomic, getter=isDrawSelf, assign) BOOL drawSelf;

/**
 需要刷新的回调
 */
@property (nonatomic, copy) void(^needDisplay)();

/**
 *  @brief 设置run 替换图片为字符等操作,子类根据需要重写
 *
 *  @param attributedString 需要绘制的文本
 */
- (void)configRun:(NSMutableAttributedString *)attributedString;

/**
 *  @brief 找出需要特别处理的run
 *
 *  @param string   需要绘制的string
 *  @param runArray run存储的数组
 */
- (void)parseText:(NSString *)string textRunsArray:(NSMutableArray *)runArray;


/**
 绘制自己 ,如果需要绘制自己 则 drawSelf 属性 需要设为YES
 
 @param rect 绘制自己的区域
 */
- (void)drawRunWithRect:(CGRect)rect;



@end


FOUNDATION_EXPORT NSString * const kPFTextAttributeName;

