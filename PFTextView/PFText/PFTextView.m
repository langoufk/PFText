//
//  PFTextView.m
//  PFTextView
//
//  Created by 龙鹏飞 on 2016/11/10.
//  Copyright © 2016年 https://github.com/LongPF/PFText. All rights reserved.
//

#import "PFTextView.h"

@interface PFTextView ()

@property (nonatomic, strong) NSMutableArray *runs; //需要特殊处理的run的数组
@property (nonatomic, strong) NSMutableDictionary *runRectDictionary; //储存每个PFRichTextRun的CGRect
@property (nonatomic, strong) NSMutableAttributedString *attributeString;
@property (nonatomic, strong) NSDictionary *universalAttributes; //加在整个text上的属性
@property (nonatomic, assign) BOOL needHeightToFit;

@end

@implementation PFTextView

#pragma mark - life cycle

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self initialize];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self initialize];
    }
    return self;
}

- (void)initialize
{
    self.runs = [NSMutableArray array];
    self.runRectDictionary = [NSMutableDictionary dictionary];
    
    _lineSpacing = 2;
    _font = [UIFont systemFontOfSize:12];
    _textColor = [UIColor blackColor];
    _text = @"";
    _firstLineHeadIndent = 0;
    _paragraphHeadIndent = 0;
    _paragraphTailIndent = 0;
    _needHeightToFit = NO;
    self.backgroundColor = [UIColor lightGrayColor];
}

- (void)dealloc
{
    NSLog(@"[PFRichTextView dealloc]");
}

#pragma mark - draw

- (void)drawRect:(CGRect)rect
{
    [self.runRectDictionary removeAllObjects];
    
    //解析文本 找出需要特殊处理的run
    if (self.runs.count == 0) {
        [self parseText:self.text runs:self.runs];
    }
    
    //配置 文本
    [self createAttributedString];
    
    //把特殊run的属性 写到 attString 里面
    __weak typeof(self) wself = self;
    for (PFTextRun *run in self.runs) {
        
        [run configRun:_attributeString];
        
        run.needDisplay = ^{
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (wself.needHeightToFit) {
                    [wself heightToFit];
                }
                [wself setNeedsDisplay];
            });
        };
    }
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    //修正坐标系
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformMakeTranslation(0, self.bounds.size.height);
    transform = CGAffineTransformScale(transform, 1, -1);
    CGContextConcatCTM(context, transform);
    
    
    CGMutablePathRef pathRef = CGPathCreateMutable();
    CGPathAddRect(pathRef, NULL, self.bounds);
    
    CTFramesetterRef framesetterRef = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)_attributeString);
    CTFrameRef frameRef = CTFramesetterCreateFrame(framesetterRef, CFRangeMake(0, 0), pathRef, NULL);
    
    CFArrayRef lines = CTFrameGetLines(frameRef);
    
    CGPoint lineOrigins[CFArrayGetCount(lines)];
    CTFrameGetLineOrigins(frameRef, CFRangeMake(0, 0), lineOrigins);
    
    //绘制
    NSInteger lastLineIndex = [self drawLineByLine:lines lineOrigins:lineOrigins context:context];
    
    //将每一个的PFRichTextRun的rect储存起来
    for (int i = 0; i < CFArrayGetCount(lines); i++) {
        
        if (lastLineIndex > 0 &&  i >= lastLineIndex) {
            break;
        }
        
        CTLineRef lineRef = CFArrayGetValueAtIndex(lines, i);
        CGPoint lineOrigin = lineOrigins[i];
        
        [self storeRunRectAndDrawRunSelf:lineRef lineOrigin:lineOrigin];
        
        
    }
    
    
    CFRelease(pathRef);
    CFRelease(frameRef);
    CFRelease(framesetterRef);
    UIGraphicsEndImageContext();
    
}

/**
 绘制除了最后一行的行元素  一行一行的绘制,  方便处理 lineBreakMode,numberOfLines, 返回最后一行的角标
 
 @param lines       每行的数组
 @param lineOrigins 每行的起点
 @param context     绘制上下文
 
 @return 返回最后一行的角标
 */
- (NSInteger)drawLineByLine:(CFArrayRef)lines lineOrigins:(CGPoint *)lineOrigins context:(CGContextRef)context;
{
    
    NSInteger lineCount = CFArrayGetCount(lines);
    
    if (lineCount < 1) return 0;
    
    for (NSInteger i = 0; i < lineCount - 1 && (_numberOfLines==0 || i < _numberOfLines); i++) {
        
        CTLineRef lineRef = CFArrayGetValueAtIndex(lines, i);
        CGPoint lineOrigin = lineOrigins[i];
        CGContextSetTextPosition(context, lineOrigin.x, lineOrigin.y);
        CTLineDraw(lineRef, context);
    }
    
    NSInteger lastIndex = (_numberOfLines==0 || _numberOfLines > lineCount) ? lineCount-1 : _numberOfLines-1;
    CGPoint lastLineOrigin = lineOrigins[lastIndex];
    CGContextSetTextPosition(context, lastLineOrigin.x, lastLineOrigin.y);
    
    CTLineRef lastLine = CFArrayGetValueAtIndex(lines, lastIndex);
    
    NSLog(@"%ld",CTLineGetStringRange(lastLine).location+CTLineGetStringRange(lastLine).length);
    NSLog(@"%ld",_attributeString.string.length);
    
    
    if ((self.lineBreakMode != NSLineBreakByTruncatingHead && self.lineBreakMode != NSLineBreakByTruncatingTail && self.lineBreakMode != NSLineBreakByTruncatingMiddle) ||
        (CTLineGetStringRange(lastLine).location+CTLineGetStringRange(lastLine).length == _attributeString.string.length))
    {
        CTLineDraw(lastLine, context);
    }else{
        
        CTLineBreakMode lineBreak = (CTLineBreakMode)self.lineBreakMode;
        CTParagraphStyleSetting lineBreakStyle;
        lineBreakStyle.spec = kCTParagraphStyleSpecifierLineBreakMode;
        lineBreakStyle.value = &lineBreak;
        lineBreakStyle.valueSize = sizeof(CTLineBreakMode);
        
        CTParagraphStyleSetting firstLineHeadIndent;
        firstLineHeadIndent.spec = kCTParagraphStyleSpecifierFirstLineHeadIndent;
        firstLineHeadIndent.value = &_firstLineHeadIndent;
        firstLineHeadIndent.valueSize = sizeof(CGFloat);
        
        CTParagraphStyleSetting headIndent;
        headIndent.spec = kCTParagraphStyleSpecifierHeadIndent;
        headIndent.value = &_paragraphHeadIndent;
        headIndent.valueSize = sizeof(CGFloat);
        
        CTParagraphStyleSetting tailIndent;
        tailIndent.spec = kCTParagraphStyleSpecifierTailIndent;
        tailIndent.value = &_paragraphTailIndent;
        tailIndent.valueSize = sizeof(CGFloat);
        
        CTParagraphStyleSetting settings[] = {lineBreakStyle,firstLineHeadIndent,headIndent,tailIndent};
        CTParagraphStyleRef paragraphStyle = CTParagraphStyleCreate(settings, 4);
        
        CFAttributedStringSetAttribute((CFMutableAttributedStringRef)_attributeString, CFRangeMake(CTLineGetStringRange(lastLine).location, CTLineGetStringRange(lastLine).length), kCTParagraphStyleAttributeName, paragraphStyle);
        
        //省略号
        static NSString* const kEllipsesCharacter = @"\u2026";
        NSAttributedString *ellipsesChar = [[NSAttributedString alloc] initWithString:kEllipsesCharacter attributes:self.universalAttributes];
        
        NSInteger lastLineLocation = CTLineGetStringRange(lastLine).location;
        NSInteger lastLineLength = CTLineGetStringRange(lastLine).length;;
        
        //最后一行的字符串
        NSMutableAttributedString *subAttributedString = [[_attributeString attributedSubstringFromRange:NSMakeRange(lastLineLocation, lastLineLength)] mutableCopy];
        
        NSInteger insertCharacterLocation = lastLineLength - 1;
        
        if (self.lineBreakMode == NSLineBreakByTruncatingHead) {
            insertCharacterLocation = 0;
        }
        else if (self.lineBreakMode == NSLineBreakByTruncatingMiddle){
            CFArrayRef lastLineRuns = CTLineGetGlyphRuns(lastLine);
            NSInteger lastLineRunCount = CFArrayGetCount(lastLineRuns) ;
            CTRunRef lastLineMiddleRun = CFArrayGetValueAtIndex(lastLineRuns, (NSInteger)lastLineRunCount/2);
            CFRange lastLineMiddleRunRange = CTRunGetStringRange(lastLineMiddleRun);
            insertCharacterLocation = (lastLineMiddleRunRange.location-lastLineLocation) + lastLineMiddleRunRange.length;
        }
        
        [subAttributedString deleteCharactersInRange:NSMakeRange(lastLineLength-1, 1)];
        [subAttributedString insertAttributedString:ellipsesChar atIndex:insertCharacterLocation];
        
        CFAttributedStringSetAttribute((CFMutableAttributedStringRef)subAttributedString, CFRangeMake(0, subAttributedString.length), kCTParagraphStyleAttributeName, paragraphStyle);
        
        CTLineRef lastLineSub = CTLineCreateWithAttributedString((CFMutableAttributedStringRef)subAttributedString);
        CGPoint lastLineOrigin = lineOrigins[lastIndex];
        CGContextSetTextPosition(context, lastLineOrigin.x, lastLineOrigin.y);
        
        CTLineDraw(lastLineSub, context);
        
        [self storeRunRectAndDrawRunSelf:lastLineSub lineOrigin:lastLineOrigin];
        
        CFRelease(lastLineSub);
        CFRelease(paragraphStyle);
    }
    
    return lastIndex;
    
}

- (void)storeRunRectAndDrawRunSelf:(CTLineRef)lineRef lineOrigin:(CGPoint)lineOrigin
{
    
    CGFloat lineAscent,lineDescent,lineLeading;
    CTLineGetTypographicBounds(lineRef, &lineAscent, &lineDescent, &lineLeading);
    CFArrayRef runs = CTLineGetGlyphRuns(lineRef);
    
    for (int j = 0; j < CFArrayGetCount(runs); j++) {
        
        CTRunRef runRef = CFArrayGetValueAtIndex(runs, j);
        CGFloat runAscent, runDescent;
        CGRect runRect;
        
        runRect = CGRectMake(lineOrigin.x+CTLineGetOffsetForStringIndex(lineRef,
                                                                        CTRunGetStringRange(runRef).location, NULL),
                             lineOrigin.y,
                             CTRunGetTypographicBounds(runRef, CFRangeMake(0, 0), &runAscent,&runDescent, NULL),
                             runAscent+runDescent);
        
        NSDictionary *attributes = (__bridge NSDictionary *)CTRunGetAttributes(runRef);
        PFTextRun *richTextRun = [attributes objectForKey:kPFTextAttributeName];
        
        if (richTextRun && richTextRun.isDrawSelf) {
            
            [richTextRun drawRunWithRect:runRect];
            [self.runRectDictionary setObject:richTextRun forKey:[NSValue valueWithCGRect:runRect]];
            
        }else if (richTextRun){
            
            [self.runRectDictionary setObject:richTextRun forKey:[NSValue valueWithCGRect:runRect]];
            
        }
        
    }
}

#pragma mark - createAttributedString

- (void)createAttributedString
{
    _attributeString = [[NSMutableAttributedString alloc] initWithString:self.text];
    
    CTFontRef fontRef = CTFontCreateWithName((CFStringRef)[self.font fontName], [self.font pointSize], &CGAffineTransformIdentity);
    CFAttributedStringSetAttribute((CFMutableAttributedStringRef)_attributeString, CFRangeMake(0, _attributeString.string.length), kCTFontAttributeName, fontRef);
    
    CFAttributedStringSetAttribute((CFMutableAttributedStringRef)_attributeString, CFRangeMake(0, _attributeString.string.length), kCTForegroundColorAttributeName, self.textColor.CGColor);
    
    
    static NSDictionary *alignments;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        alignments = @{
                       @(NSTextAlignmentCenter):@(kCTTextAlignmentCenter),
                       @(NSTextAlignmentRight):@(kCTTextAlignmentRight)
                       };
    });
    CTTextAlignment alignment = [alignments[@(self.textAlignment)] unsignedCharValue]?:kCTTextAlignmentLeft;
    CTParagraphStyleSetting alignmentStyle;
    alignmentStyle.spec = kCTParagraphStyleSpecifierAlignment;
    alignmentStyle.value = &alignment;
    alignmentStyle.valueSize = sizeof(alignment);
    
    CTParagraphStyleSetting lineSpaceStyle;
    CGFloat lineSpacing = self.lineSpacing;
    lineSpaceStyle.spec = kCTParagraphStyleSpecifierLineSpacingAdjustment;
    lineSpaceStyle.value = &lineSpacing;
    lineSpaceStyle.valueSize = sizeof(CGFloat);
    
    CTParagraphStyleSetting firstLineHeadIndent;
    CGFloat firstLineHeadIndentValue = self.firstLineHeadIndent;
    firstLineHeadIndent.spec = kCTParagraphStyleSpecifierFirstLineHeadIndent;
    firstLineHeadIndent.value = &firstLineHeadIndentValue;
    firstLineHeadIndent.valueSize = sizeof(CGFloat);
    
    CTParagraphStyleSetting headIndent;
    CGFloat headIndentValue = self.paragraphHeadIndent;
    headIndent.spec = kCTParagraphStyleSpecifierHeadIndent;
    headIndent.value = &headIndentValue;
    headIndent.valueSize = sizeof(CGFloat);
    
    CTParagraphStyleSetting tailIndent;
    CGFloat tailIndentValue = self.paragraphTailIndent;
    tailIndent.spec = kCTParagraphStyleSpecifierTailIndent;
    tailIndent.value = &tailIndentValue;
    tailIndent.valueSize = sizeof(CGFloat);
    
    CTParagraphStyleSetting settings[] = {alignmentStyle,lineSpaceStyle,firstLineHeadIndent,headIndent,tailIndent};
    CTParagraphStyleRef paragraphStyle = CTParagraphStyleCreate(settings, 5);
    
    // 如果lineBreakMode设置... 就只显示一行
    if (self.lineBreakMode != NSLineBreakByTruncatingHead && self.lineBreakMode != NSLineBreakByTruncatingTail && self.lineBreakMode != NSLineBreakByTruncatingMiddle) {
        CTLineBreakMode lineBreak = (CTLineBreakMode)self.lineBreakMode;
        CTParagraphStyleSetting lineBreakStyle;
        lineBreakStyle.spec = kCTParagraphStyleSpecifierLineBreakMode;
        lineBreakStyle.value = &lineBreak;
        lineBreakStyle.valueSize = sizeof(CTLineBreakMode);
        
        CTParagraphStyleSetting settings[] = {lineBreakStyle,alignmentStyle,lineSpaceStyle,firstLineHeadIndent,headIndent,tailIndent};
        paragraphStyle = CTParagraphStyleCreate(settings, 6);
    }
    
    
    CFAttributedStringSetAttribute((CFMutableAttributedStringRef)_attributeString, CFRangeMake(0, _attributeString.string.length), kCTParagraphStyleAttributeName, paragraphStyle);
    
    CFRelease(paragraphStyle);
    
    if (_attributeString.string.length > 0) {
        self.universalAttributes = [_attributeString attributesAtIndex:0 effectiveRange:NULL];
    }
}

#pragma mark - get special runs

- (void)parseText:(NSString *)string runs:(NSMutableArray *)runs
{
    for (PFTextRun *settingRun in self.settingRuns) {
        
        [settingRun parseText:string textRunsArray:runs];
        
    }
}




#pragma mark - fit

- (CGFloat)heightThatFit:(CGFloat)width
{
    if (width == 0.0) {
        width = self.bounds.size.width;
    }
    
    if (self.runs.count == 0) {
        [self parseText:self.text runs:self.runs];
    }
    
    [self createAttributedString];
    
    for (PFTextRun *run in self.runs) {
        [run configRun:_attributeString];
    }
    
    CGMutablePathRef pathRef = CGPathCreateMutable();
    CGPathAddRect(pathRef, NULL, CGRectMake(0, 0, width, MAXFLOAT));
    
    CTFramesetterRef framesetterRef = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)_attributeString);
    CTFrameRef frameRef = CTFramesetterCreateFrame(framesetterRef, CFRangeMake(0, 0), pathRef, NULL);
    
    CFArrayRef lines = CTFrameGetLines(frameRef);
    NSInteger lineCount = CFArrayGetCount(lines);
    
    if (lineCount == 0) return 0;
    
    NSInteger lastLineIndex = (_numberOfLines==0 || _numberOfLines > lineCount) ? lineCount - 1: _numberOfLines - 1;
    CTLineRef lastLine = CFArrayGetValueAtIndex(lines, lastLineIndex);
    CFRange fitRange = CFRangeMake(0, CTLineGetStringRange(lastLine).location+CTLineGetStringRange(lastLine).length);
    CGSize fitSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetterRef, fitRange, NULL, CGSizeMake(width, MAXFLOAT), &fitRange);
    
    CFRelease(pathRef);
    CFRelease(framesetterRef);
    CFRelease(frameRef);
    
    return fitSize.height;
}

- (void)heightToFit
{
    CGFloat fitHeight = [self heightThatFit:self.bounds.size.width];
    CGRect fitRect = self.frame;
    fitRect.size.height = fitHeight;
    self.frame = fitRect;
    self.needHeightToFit = YES;
}

#pragma mark - touches

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    
    CGPoint location = [(UITouch *)[touches anyObject] locationInView:self];
    CGPoint runLocation = CGPointMake(location.x, self.frame.size.height - location.y);
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(textView:touchBeginRun:)])
    {
        __weak typeof(self) wself = self;
        
        [self.runRectDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
            
            CGRect rect = [((NSValue *)key) CGRectValue];
            if(CGRectContainsPoint(rect, runLocation))
            {
                [wself.delegate textView:wself touchBeginRun:obj];
            }
        }];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    
    CGPoint location = [(UITouch *)[touches anyObject] locationInView:self];
    CGPoint runLocation = CGPointMake(location.x, self.frame.size.height - location.y);
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(textView:touchEndRun:)])
    {
        __weak typeof(self) wself = self;
        
        [self.runRectDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
            
            CGRect rect = [((NSValue *)key) CGRectValue];
            if(CGRectContainsPoint(rect, runLocation))
            {
                [wself.delegate textView:wself touchEndRun:obj];
            }
        }];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    
    CGPoint location = [(UITouch *)[touches anyObject] locationInView:self];
    CGPoint runLocation = CGPointMake(location.x, self.frame.size.height - location.y);
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(textView: touchCanceledRun:)])
    {
        __weak typeof(self) wself = self;
        
        [self.runRectDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
            
            CGRect rect = [((NSValue *)key) CGRectValue];
            if(CGRectContainsPoint(rect, runLocation))
            {
                [wself.delegate textView:wself touchCanceledRun:obj];
            }
        }];
    }
}
#pragma mark - getters / setters

- (void)setSettingRuns:(NSArray<PFTextRun *> *)settingRuns
{
    if (_settingRuns != settingRuns) {
        [self setNeedsDisplay];
        _settingRuns = settingRuns;
        [self.runs removeAllObjects];
    }
}

- (void)setLineSpacing:(CGFloat)lineSpacing
{
    if (_lineSpacing != lineSpacing) {
        [self setNeedsDisplay];
        _lineSpacing = lineSpacing;
        [_runRectDictionary removeAllObjects];
    }
}

- (void)setText:(NSString *)text
{
    if (_text != text) {
        [self setNeedsDisplay];
        _text = text;
        [self.runs removeAllObjects];
    }
}

- (void)setFont:(UIFont *)font
{
    if (_font != font) {
        [self setNeedsDisplay];
        _font = font;
    }
    
}

- (void)setTextColor:(UIColor *)textColor
{
    if (textColor != _textColor) {
        [self setNeedsDisplay];
        _textColor = textColor;
    }
}

- (void)setParagraphHeadIndent:(CGFloat)paragraphHeadIndent
{
    if (_paragraphHeadIndent != paragraphHeadIndent) {
        [self setNeedsDisplay];
        _paragraphHeadIndent = paragraphHeadIndent;
    }
}

- (void)setParagraphTailIndent:(CGFloat)paragraphTailIndent
{
    if (_paragraphTailIndent != paragraphTailIndent) {
        [self setNeedsDisplay];
        _paragraphTailIndent = paragraphTailIndent;
    }
}

- (void)setFirstLineHeadIndent:(CGFloat)firstLineHeadIndent
{
    if (_firstLineHeadIndent != firstLineHeadIndent) {
        [self setNeedsDisplay];
        _firstLineHeadIndent = firstLineHeadIndent;
    }
}

- (void)setNumberOfLines:(NSInteger)numberOfLines
{
    if (_numberOfLines != numberOfLines) {
        [self setNeedsDisplay];
        _numberOfLines = numberOfLines;
    }
}


@end