//
//  WTEDNReader.m
//  edn-objc
//
//  Created by Jason Jobe on 12/10/14.
//  Copyright (c) 2014 Ben Mosher. All rights reserved.
//

#import "WTEDNReader.h"

#import "BMOEDNSymbol.h"
#import "BMOEDNList.h"
#import "BMOEDNTaggedElement.h"
#import "NSObject+BMOEDN.h"
#import "BMOEDNCharacter.h"
#import "BMOEDNRatio.h"
#import "WTToken.h"


static NSCharacterSet *whitespace, *digits, *symbolChars,*delimiters;
static id CLOSE_P;
static id CLOSE_B;
static id CLOSE_CB;

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
static inline char getChar (WTEDNReader *reader)
{
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

static inline BOOL skipWhitespace (WTEDNReader *reader) {
    char ch = getChar (reader);
    while ([whitespace characterIsMember:ch]) {
        ch = getChar (reader);
    }
    if (ch == '\0') return YES;
    pushBackChar(reader, ch);
    return NO;
}

static inline void advanceToDelimiter (WTEDNReader *reader) {
    char ch = getChar (reader);
    while (! (ch == '\0' || [delimiters characterIsMember:ch])) {
        ch = getChar (reader);
    }
    if (ch == '\0') ++(reader->_currentNdx);
    
    pushBackChar(reader, ch);
}


@implementation WTEDNReader

+(void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{

        whitespace = [NSCharacterSet whitespaceCharacterSet];
        digits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];

//        NSMutableCharacterSet *alpha = [NSMutableCharacterSet alphanumericCharacterSet];
//        [alpha addCharactersInString:@".*+!-_?$%&=:#/<>"];
//        symbolChars = [alpha copy];

        NSMutableCharacterSet *cset = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
        [cset addCharactersInString:@"{}()[]"];
        delimiters = [cset copy];
        
        numberFormatter = [[NSNumberFormatter alloc] init];
        numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        
        CLOSE_P = @(')');
        CLOSE_B = @(']');
        CLOSE_CB = @('}');
        
        literalValues =
        @{
          @"true": @YES,
          @"false": @NO,
          
          @"YES": @YES,
          @"NO": @NO,
          
          @('n'): [BMOEDNCharacter characterWithUnichar:'\n'],
          @('t'): [BMOEDNCharacter characterWithUnichar:'\t'],
          @(' '): [BMOEDNCharacter characterWithUnichar:' '],
          
          @"space":[BMOEDNCharacter characterWithUnichar:' '],
          @"newline":[BMOEDNCharacter characterWithUnichar:'\n'],
          @"tab":[BMOEDNCharacter characterWithUnichar:'\t'],
          @"return":[BMOEDNCharacter characterWithUnichar:'\r'],
          
          @"nil": [NSNull null],
          };
    });
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
    BOOL done;

start:
    done = skipWhitespace (self);
    if (done) return nil;
    
    unichar pch, ch = getChar(self);
    id result;
    id key, sexpr;
    
    switch (ch)
    {
        // OPEN
        case '{':
            result = [NSMutableDictionary new];
            do {
                if (CLOSE_CB != (key = [self read])) {
                    sexpr = [self read];
                    if (key && sexpr) {
                        [result setObject:sexpr forKey:key];
                    }
                    else {
                        [[NSException exceptionWithName:@"WTEDNReader Error" reason:@"Unbalanced map" userInfo:nil] raise];
                    }
                }
            }
            while (key != CLOSE_CB);
            
            break;
            
        case '(':
            result = [BMOEDNList new];
            for (sexpr = [self read]; sexpr && sexpr != CLOSE_P; sexpr = [self read]) {
                if (sexpr == nil) {
                    [[NSException exceptionWithName:@"WTEDNReader Error" reason:@"Unbalanced list" userInfo:nil] raise];
                }
                [result addObject:sexpr];
            }
            break;

        case '[':
            result = [NSMutableArray new];
            for (sexpr = [self read]; sexpr && sexpr != CLOSE_B; sexpr = [self read]) {
                if (sexpr == nil) {
                    [[NSException exceptionWithName:@"WTEDNReader Error" reason:@"Unbalanced list" userInfo:nil] raise];
                }
                [result addObject:sexpr];
            }
            break;

        // CLOSE
        case '}': return CLOSE_CB;
        case ']': return CLOSE_B;
        case ')': return CLOSE_P;

        // QUOTED STRING
        case '"':
        case '\'':
            result = [self readStringClosedByChar:ch];
            break;
        case '\\':
            result = [self readCharacter];
            break;
            
        case '\n':
            ++_currentLine;
            goto start;
            
        case '\0':
            // EOF
            return nil;
        
        case '#':
            pch = peekAtNextChar (self);
            if (pch == '_') {
                ch = getChar(self);
                [self read]; // discard the next expression
                return [self read];
            }
            else if (pch == '{') {
                result = [NSMutableSet new];
                for (sexpr = [self read]; sexpr && sexpr != CLOSE_CB; sexpr = [self read]) {
                    [result addObject:sexpr];
                }
            }
            else {
                result = [BMOEDNTaggedElement elementWithTag:[self read] element:[self read]];
            }
            break;
            
        case '^': {
            id metadata = [self read];
            result = [self read];
            if ([result supportsEdnMetadata]) {
                [result setEdnMetadata:metadata];
            }
        }
        break;
            
        case '+':
        case '-':
            pch = peekAtNextChar (self);
            pushBackChar(self, ch);
            if ([digits characterIsMember:pch]) {
                result = [self readNumber];
            }
            else {
                result = [self readSymbol];
            }
            break;
        default:
            pushBackChar(self, ch);
            if ([digits characterIsMember:ch]) {
                result = [self readNumber];
            }
            result = [self readSymbol];
    }
    if (self.options & WTEDNReaderDebug) {
        WTToken *token = [WTToken tokenFor:result];
        token.lineno = _currentLine;
        token.column = _currentColumn;
        return token;
    }
    else {
        return result;
    }
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
    char ch = peekAtNextChar(self);
    if (ch == '+') {
        ch = getChar(self);
    }
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
                initWithBytes:&_bytes[mark] length:(end_mark - mark) encoding:NSUTF8StringEncoding];
    }
    else {
        name = [[NSString alloc]
                initWithBytes:&_bytes[namespace_mark + 1] length:(end_mark - namespace_mark - 1)
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
