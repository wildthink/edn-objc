//
//  WTEDNReader.m
//  edn-objc
//
//  Created by Jason Jobe on 12/10/14.
//  Copyright (c) 2014 Ben Mosher. All rights reserved.
//

#import "WTEDNReader.h"

#import "BMOEDNSymbol.h"
#import "BMOEDNKeyword.h"
#import "BMOEDNList.h"
#import "BMOEDNTaggedElement.h"
#import "BMOEDNRepresentation.h"
#import "BMOEDNRegistry.h"
#import "NSObject+BMOEDN.h"
#import "BMOEDNRoot.h"
#import "BMOLazyEnumerator.h"
#import "BMOEDNCharacter.h"
#import "BMOEDNError.h"
#import "BMOEDNRatio.h"

static NSCharacterSet *whitespace, *newline, *quoted,*numberPrefix,*digits,*symbolChars,*number_delimiters;
static NSString *CLOSE = @"_CLOSE_";
static NSDictionary *literalValues;
static NSNumberFormatter *numberFormatter;

@interface WTEDNReader () {
    @public
    const char *_bytes;
    NSUInteger _dataLength;
    NSUInteger _currentNdx;
    NSUInteger _currentLine;
    NSUInteger _currentColumn;
}

@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) NSError *error;


//@property (nonatomic, strong) NSMutableArray *stack;

@end


static inline char peekAtNextChar (WTEDNReader *reader) {
    if (reader->_currentNdx >= reader->_dataLength) {
        return '\0';
    }
    char ch = reader->_bytes[reader->_currentNdx];
    return ch;
}

// NOTE: Handling the column is a good bit tricker when pushBack is supported :-(
// Skipping that case for now.
static inline char getChar (WTEDNReader *reader) {
    if (reader->_currentNdx >= reader->_dataLength) {
        return '\0';
    }
    char ch = reader->_bytes[reader->_currentNdx];
    ++(reader->_currentNdx);
    if (ch == '\n') {
        ++(reader->_currentLine);
        reader->_currentColumn = 0;
    }
    else {
        ++(reader->_currentColumn);
    }
    return ch;
}

static inline void pushBackChar (WTEDNReader *reader, char ch) {
    
    if (ch == '\0') {
        return;
    }
    --(reader->_currentNdx);

    if (ch == '\n') {
        --(reader->_currentLine);
        // BAD!! reader->_currentColumn = 0;
    }
    else {
        --(reader->_currentColumn);
    }
    if (ch != reader->_bytes[reader->_currentNdx]) {
        [[NSException exceptionWithName:@"WTEDNReader Error" reason:@"Incorrect pushBackChar" userInfo:nil] raise];
    }
}

static inline void skipWhitespace (WTEDNReader *reader) {
    char ch = getChar (reader);
    while ([whitespace characterIsMember:ch]) {
        ch = getChar (reader);
    }
    pushBackChar(reader, ch);
}

static inline void advanceToDelimiter (WTEDNReader *reader) {
    char ch = getChar (reader);
    while (! (ch == '\0' || [number_delimiters characterIsMember:ch])) {
        ch = getChar (reader);
    }
    if (ch == '\0') ++(reader->_currentNdx);
    
    pushBackChar(reader, ch);
}


@implementation WTEDNReader

+(void)initialize
{
    if (whitespace == nil) {
        whitespace = [NSCharacterSet whitespaceCharacterSet];
    }
    if (newline == nil) {
        newline = [NSCharacterSet newlineCharacterSet];
    }
    if (quoted == nil) {
        quoted = [NSCharacterSet characterSetWithCharactersInString:@"\\\"rnt"];
    }
    if (numberPrefix == nil) {
        numberPrefix = [NSCharacterSet characterSetWithCharactersInString:@"+-."];
    }
    if (digits == nil) {
        digits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    }
    if (symbolChars == nil) {
        NSMutableCharacterSet *alpha = [NSMutableCharacterSet alphanumericCharacterSet];
        [alpha addCharactersInString:@".*+!-_?$%&=:#/<>"];
        symbolChars = [alpha copy];
    }
    if (number_delimiters == nil) {
        NSMutableCharacterSet *cset = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
        [cset addCharactersInString:@"{}()[]"];
        number_delimiters = [cset copy];
    }
    
    if (! numberFormatter) {
        numberFormatter = [[NSNumberFormatter alloc] init];
        numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    }
    
    if (literalValues == nil) {
        literalValues =
        @{
          @"true": @YES,
          @"false": @NO,
          
          @"YES": @YES,
          @"NO": @NO,
          
          @('n'): [BMOEDNCharacter characterWithUnichar:'\n'],
          @('t'): [BMOEDNCharacter characterWithUnichar:'\t'],
          @(' '): [BMOEDNCharacter characterWithUnichar:' '],
          
          @"nil": [NSNull null],
        };
    }
}

+ readString:(NSString*)str error:(NSError **)error {
    WTEDNReader *reader = [[self alloc] initWithString:str];
    return [reader read];
}

+ readData:(NSData*)data error:(NSError **)error {
    WTEDNReader *reader = [[self alloc] initWithData:data];
    return [reader read];
}

- (instancetype)initWithString:(NSString*)str
{
    return [self initWithData:[str dataUsingEncoding:NSUTF8StringEncoding]];
}

- initWithData:(NSData*)data
{
    self.data = data;
    _bytes = data.bytes;
    _dataLength = data.length;
    return self;
}

- (NSString*)debugDescription {
    NSUInteger len = 8;
    return [[NSString alloc] initWithBytesNoCopy:(void*)(&_bytes[_currentNdx])
                                          length:len encoding:NSUTF8StringEncoding freeWhenDone:NO];
}

- read
{
start:
    skipWhitespace (self);
    
    unichar pch, ch = getChar(self);
    id result;
    id key, sexpr;
    
    switch (ch)
    {
        // OPEN
        case '{':
            result = [NSMutableDictionary new];
            do {
                if (CLOSE != (key = [self read])) {
                    sexpr = [self read];
                    if (key && sexpr) {
                        [result setObject:sexpr forKey:key];
                    }
                }
            }
            while (key == CLOSE);
            
            break;
            
        case '(':
        case '[':
            result = [NSMutableArray new];
            for (sexpr = [self read]; sexpr && sexpr != CLOSE; sexpr = [self read]) {
                [result addObject:sexpr];
            }
            break;

        // CLOSE
        case '}': case ']': case ')':
            return CLOSE;
            break;
        
        case '"':
        case '\'':
            return [self readStringClosedByChar:ch];
        
        case '\\':
            return [self readCharacter];
            break;
            
        case '\n':
            ++_currentLine;
            goto start;
            
        case '\0':
            // EOF
            return nil;
            
        case '+':
        case '-':
        case '.':
            pch = peekAtNextChar (self);
            pushBackChar(self, ch);
            if ([digits characterIsMember:pch]) {
                return [self readNumber];
            }
            break;
        default:
            pushBackChar(self, ch);
            if ([digits characterIsMember:ch]) {
                return [self readNumber];
            }
            return [self readSymbol];
    }
    return result;
}

- readCharacter
{
    NSInteger mark = _currentNdx;
    advanceToDelimiter (self);
    if (_currentNdx - mark == 1) {
        char ch = getChar(self);
        id value = literalValues[@(ch)];
        return (value ? value : [BMOEDNCharacter characterWithUnichar:ch]);
    }
    else {
        NSString *str = [[NSString alloc]
                         initWithBytes:&_bytes[mark] length:(_currentNdx - mark - 1) encoding:NSUTF8StringEncoding];
        id value = literalValues[str];
        return value;
    }
}

- readNumber
{
    NSInteger mark = _currentNdx;
    advanceToDelimiter (self);
    NSString *str = [[NSString alloc]
                     initWithBytes:&_bytes[mark] length:(_currentNdx - mark - 1) encoding:NSUTF8StringEncoding];
    return [numberFormatter numberFromString:str];
}

- (NSString*)readStringClosedByChar:(char)closingChar
{
    NSInteger mark = _currentNdx;
    char ch = getChar(self);
    
    while (ch != closingChar) {
        if (ch == '\\') {
            ch = getChar(self);
        }
        ch = getChar(self);
    }
    NSString *str = [[NSString alloc]
                     initWithBytes:&_bytes[mark] length:(_currentNdx - mark - 1) encoding:NSUTF8StringEncoding];
    return str;
}

- readSymbol
{
    NSInteger mark = _currentNdx;
    NSInteger namespace_mark = -1;
    
    char ch = getChar(self);
    
    while ([symbolChars characterIsMember:ch]) {
        ch = getChar(self);
        if (ch == '/') namespace_mark = _currentNdx - 1;
    }
    
    NSInteger end_mark = _currentNdx;
    
    // Symbols parse identically
    // We simply need to check if we have one
    Class symbolClass = [BMOEDNSymbol class];
    
    // If the symbol starts with
    if (_bytes[mark] == ':') {
        symbolClass = [BMOEDNKeyword class];
        ++mark;
    }
    if ( !(self.options & WTEDNReaderStrict) && _bytes[end_mark - 2] == ':') {
        symbolClass = [BMOEDNKeyword class];
        --end_mark;
    }
    
    pushBackChar(self, ch);

    NSString *namespace = (namespace_mark < 0 ? nil :
                           [[NSString alloc] initWithBytes:&_bytes[mark] length:(namespace_mark - mark)
                                                  encoding:NSUTF8StringEncoding]);

    NSString *name;
    
    if (namespace_mark < 0)
    {
        name = [[NSString alloc]
                initWithBytes:&_bytes[mark] length:(end_mark - mark - 1) encoding:NSUTF8StringEncoding];
    }
    else {
        name = [[NSString alloc]
                initWithBytes:&_bytes[namespace_mark + 1] length:(end_mark - namespace_mark - 2)
                     encoding:NSUTF8StringEncoding];
    }
    
    // Check for literal symbols
    if (namespace == nil)
    {
        id value = literalValues[name];
        if (value) return value;
    }
    
    BMOEDNSymbol *symbol = [symbolClass symbolWithNamespace:namespace name:name];
    return symbol;
}

@end
