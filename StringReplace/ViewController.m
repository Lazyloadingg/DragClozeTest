//
//  ViewController.m
//  StringReplace
//
//  Created by Lazyloading on 2022/7/29.
//

#import "ViewController.h"
#import <YYText/YYText.h>


@interface ViewController ()
<
YYTextViewDelegate
>
@property(nonatomic,strong)YYTextView * textView;
@property(nonatomic,assign)CGPoint offset;
@property(nonatomic,assign)CGPoint lastPostion;
@property(nonatomic,strong)NSMutableArray * targets;
@property(nonatomic,assign)NSRange lastSelectRange;
@property(nonatomic,strong)NSMutableAttributedString * contentText;
@property(nonatomic,strong)NSString * text;
@property(nonatomic,strong)NSArray * answers;
@property(nonatomic,strong)NSMutableDictionary * save;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.textView];
    self.targets = [self coordinate];
    [self layoutAnswer];
}
#pragma mark --> 🐷 Action 🐷
//改变点击位置单词背景
- (void)tap:(UITapGestureRecognizer *)tap{
    CGPoint point = [tap locationInView:_textView];
    CGPoint position = CGPointMake(point.x, point.y);
    
    UITextPosition * textposition = [_textView closestPositionToPoint:position];
    UITextRange * range = [[_textView tokenizer] rangeEnclosingPosition:textposition withGranularity:UITextGranularityWord inDirection:1];
    NSString * text = [_textView textInRange:range];
    
    NSInteger location = [_textView offsetFromPosition:_textView.beginningOfDocument toPosition:range.start];
    NSInteger length = [_textView offsetFromPosition:range.start toPosition:range.end];
    //开始用的是系统API，但是效果不太好没法加圆角，改用YYText的YYTextBorder
    //置空上一个，保证同时只改变一个
    [self.contentText yy_setTextBackgroundBorder:nil range:self.lastSelectRange];
    //记录最后点击位置，用于下次置空
    self.lastSelectRange = NSMakeRange(location, length);
    
    YYTextBorder * border = [YYTextBorder borderWithFillColor:[UIColor.orangeColor colorWithAlphaComponent:0.6]  cornerRadius:4];
    border.insets = UIEdgeInsetsMake(1, -3, 1, -3);
    [self.contentText yy_setTextBackgroundBorder:border range:self.lastSelectRange];
    
    _textView.attributedText = self.contentText;
    NSLog(@"点击-----%@",text);
}
//拖动单词放入框中
- (void)pan:(UIPanGestureRecognizer *)pan{
    UILabel * btn = (UILabel *)pan.view;
    CGPoint point = [pan locationInView:self.view];
    switch (pan.state) {
        case UIGestureRecognizerStateBegan:{
            //记录拖拽目标起始position，方便后面恢复
            self.lastPostion = btn.layer.position;
            
            //记录拖拽点相对拖拽目标起始position的偏移，用于`Changed`时位置修正，防止一开始拖拽`闪现`问题
            self.offset = CGPointMake(btn.layer.position.x - point.x, btn.layer.position.y - point.y);
        }
            break;
            
        case UIGestureRecognizerStateChanged:{
            btn.layer.position = CGPointMake(self.offset.x + point.x, self.offset.y + point.y);
        }
            break;
            
        case UIGestureRecognizerStateEnded:{
            //如果没有要比对对象，直接返回
            if (self.targets.count == 0) {
                [UIView animateWithDuration:0.25 animations:^{
                    btn.layer.position = self.lastPostion;
                }];
                return;
            }
            //匹配结束的点是否在任意一个筛选子串范围内
            for (NSInteger index = 0; index < self.targets.count; index++) {
                NSDictionary * info = self.targets[index];
                NSString * index = info[@"index"];
                CGRect originFrame = CGRectFromString(info[@"originFrame"]);
                //扩大拖拽点范围，提升体验，值我随便写的
                CGRect moveRect = CGRectMake(point.x-10, point.y-10, 20, 20);
                //当textview滑动后，初始化时计算的坐标已不准确，因此比对时候要先转换坐标，
                CGRect rect = [self.textView convertRect:originFrame toView:self.view];
                /*
                 条件1：如果子串范围和拖拽点有交叉，说明位置正确
                 条件2：判断是不是拖拽对象应该对应的空，我这里用tag作为下标判断，也可以是其他条件
                 */
                if (CGRectIntersectsRect(rect,moveRect ) && (index.integerValue == (btn.tag - 100))) {
                    NSString * answer = [NSString stringWithFormat:@"%@",index];
                    NSMutableAttributedString * tmp = [[NSMutableAttributedString alloc]initWithString:answer];
                    [tmp addAttribute:NSForegroundColorAttributeName value:UIColor.blueColor range:NSMakeRange(0, tmp.length)];
                    [tmp addAttributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:18]} range:NSMakeRange(0, tmp.length)];
                    /*
                     1. 初始化一个填空位置frame大小的label，放上去，
                     2. 我这里一开始是把原本位置文本替换成目标文本，但是效果不太好，宽度没法和替换前保持完全一致，干脆搞一个label放上去
                     */
                    YYLabel * label = [[YYLabel alloc]initWithFrame:originFrame];
                    label.attributedText = tmp;
                    label.textAlignment = NSTextAlignmentCenter;
                    [self.textView addSubview:label];
                    
                    //到这里说明都正确，隐藏拖拽对象
                    [UIView animateWithDuration:0.1 animations:^{
                        btn.alpha = 0;
                    } completion:^(BOOL finished) {
                        btn.layer.position = self.lastPostion;
                    }];
                    return;
                }else{
                    //如果不匹配恢复原位
                    [UIView animateWithDuration:0.25 animations:^{
                        btn.layer.position = self.lastPostion;
                    }];
                    NSLog(@"没拖到");
                }
            }
        }
            NSLog(@"结束");
            break;
            
        default:
            break;
    }
}
#pragma mark --> 🐷 private method 🐷
//匹配文本中指定字符并计算frame存储
- (NSMutableArray *)coordinate{
    NSMutableAttributedString * att = self.contentText;
    
    //我这里文本中使用`_`填空占位，匹配至少连续四个`_`
    NSRegularExpression *regularExpression = [NSRegularExpression regularExpressionWithPattern:@"_{4,}" options:0 error:nil];
    
    //获取文本中所有符合匹配规则的子串结果集
    NSArray * results = [regularExpression matchesInString:self.text options:0 range:NSMakeRange(0, att.length)];
    NSMutableArray * array = [NSMutableArray arrayWithCapacity:results.count];
    //计算每一个子串的`frame`并存储，为了后面拖拽目标单词时进行比对
    for (NSInteger index = 0; index < results.count; index++) {
        NSTextCheckingResult * result = results[index];
        CGRect frame = [self boundingRectForCharacterRange:result.range string:att];
        NSDictionary * info = @{
            @"originFrame" : NSStringFromCGRect(frame)?:@"",//存储子串frame
            @"range" : NSStringFromRange(result.range)?:@"",
            @"index" : @(index + 1)//存储当前子串在文本所有筛选子串的下标，方便后面一一对应匹配
        };
        //记录每个子串的位置，下标等
        [array addObject:info];
    }
    return array;
}
//计算指定range的frame
- (CGRect)boundingRectForCharacterRange:(NSRange)range string:(NSAttributedString *)attributedText{
    //原生计算，会有偏差，最后采用的是YYText提供的方法
    //    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:attributedText];
    //    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    //    [textStorage addLayoutManager:layoutManager];
    //    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:CGSizeMake(self.textView.bounds.size.width, CGFLOAT_MAX)];
    //    [layoutManager addTextContainer:textContainer];
    //    NSRange glyphRange;
    //    [layoutManager characterRangeForGlyphRange:range actualGlyphRange:&glyphRange];
    //    CGRect rect = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];
    
    //YYText计算
    CGRect yyrect = [self.textView.textLayout rectForRange:[YYTextRange rangeWithRange:range]];
    
    //添加带背景layer方便调试
    CALayer * layer = [CALayer layer];
    layer.backgroundColor = [UIColor.greenColor colorWithAlphaComponent:0.1].CGColor;
    layer.frame = yyrect;
    [self.textView.layer addSublayer:layer];
    return yyrect;
}

//添加被拖拽对象，我这里demo随便写的布局，
- (void)layoutAnswer{
    NSInteger row = 1;
    CGFloat hspace = 10;
    CGFloat vspace = 10;
    CGFloat originY = 500;
    NSMutableArray * rects = [NSMutableArray array];
    for (NSInteger index = 0; index < self.answers.count; index++) {
        CGRect rect;
        NSString * title = _answers[index];
        CGSize size = [title boundingRectWithSize:CGSizeMake(self.view.bounds.size.width - 20, MAXFLOAT) options:0 attributes:@{NSFontAttributeName : [UIFont systemFontOfSize:18]} context:nil].size;
        if (index == 0) {
            rect = CGRectMake(hspace, originY, size.width + hspace, size.height);
        }else{
            CGRect lastrect = CGRectFromString(rects.lastObject);
            if (lastrect.size.width + lastrect.origin.x + size.width + 10 > self.view.bounds.size.width - 20) {
                row += 1;
                rect = CGRectMake(hspace , vspace + lastrect.size.height + lastrect.origin.y, size.width, size.height);
            }else{
                rect = CGRectMake(hspace + lastrect.origin.x + lastrect.size.width ,lastrect.origin.y, size.width, size.height);
            }
        }
        [rects addObject:NSStringFromCGRect(rect)];
        UILabel * label = [[UILabel alloc]initWithFrame:rect];
        label.tag = 101 + index;
        label.userInteractionEnabled = YES;
        label.text = title;
        label.font = [UIFont systemFontOfSize:18];
        UIPanGestureRecognizer * pan = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(pan:)];
        [label addGestureRecognizer:pan];
        [self.view addSubview:label];
    }
    NSLog(@"rects: %@",rects);
}
#pragma mark --> 🐷 getter 🐷
- (YYTextView *)textView{
    if (!_textView) {
        YYTextView * textView = [[YYTextView alloc]initWithFrame:CGRectMake(20, 100, 350, 350) ];
        textView.backgroundColor = [[UIColor grayColor]colorWithAlphaComponent:0.1];
        textView.font = [UIFont systemFontOfSize:20];
        textView.editable = NO;
        textView.delegate = self;
        textView.attributedText = self.contentText;
        //添加点击修改点击位置单词背景
        UITapGestureRecognizer * tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tap:)];
        [textView addGestureRecognizer:tap];
        _textView = textView;
    }
    return _textView;
}
- (NSMutableAttributedString *)contentText{
    if (!_contentText) {
        _contentText =  [[NSMutableAttributedString alloc]initWithString:self.text];
        NSMutableParagraphStyle * style = [[NSMutableParagraphStyle alloc]init];
        style.lineBreakMode  = NSLineBreakByWordWrapping;
        [_contentText addAttributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:20],NSParagraphStyleAttributeName:style } range:NSMakeRange(0, _contentText.length)];
    }
    return _contentText;
}
- (NSString *)text{
    if (!_text) {
        NSString * seg = @"____________";
        NSString * str =  [NSString stringWithFormat:@" The sheets are damp with sweat. You're cold,%@ but your heart is racing as if an assailant just chased you down a dark street. It was just a nightmare, you tell yourself; there's nothing to be afraid of. But you're still filled with %@.Given how unsettling and haunting nightmares can be, is there a way for %@ dreamers to   The sheets are damp with sweat. You're cold,%@ but your heart is racing as if an assailant just chased you down a dark street. It was just a nightmare, you tell yourself; there's nothing to be afraid of. But you're still filled with %@.Given how unsettling and haunting nightmares can be, is there a way for%@ dreamers to The sheets are damp with sweat. You're cold,%@ but your heart is racing as if an assailant just chased you down a dark street. It was just a nightmare, you tell yourself; there's nothing to be afraid of. But you're still filled with %@.Given how unsettling and haunting nightmares can be, is there a way for %@ dreamers to   The sheets are damp with sweat. You're cold,%@ but your heart is racing as if an assailant just chased you down a dark street. It was just a nightmare, you tell yourself; there's nothing to be afraid of. But you're still filled with %@.Given how unsettling and haunting nightmares can be, is there a way for%@ dreamers to",seg,seg,seg,seg,seg,seg,seg,seg,seg,seg,seg,seg];
        _text = str;
    }
    return _text;
}
- (NSArray *)answers{
    if (!_answers) {
        _answers = @[
            @"1_hello",
            @"2_world",
            @"3_unsettling",
            @"4_nightmares",
            @"5_dreamers",
            @"6_sweat"
        ];
    }
    return _answers;
}
@end
