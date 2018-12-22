// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#import <XCTest/XCTest.h>
#include "../source/BatchRenaming/BatchRenamingScheme.h"

using namespace nc::ops;

@interface BatchRenaming_Tests : XCTestCase

@end

@implementation BatchRenaming_Tests




//[N] old file name, WITHOUT extension
//[N1] The first character of the original name
//[N2-5] Characters 2 to 5 from the old name (totals to 4 characters). Double byte characters (e.g. Chinese, Japanese) are counted as 1 character! The first letter is accessed with '1'.
//[N2,5] 5 characters starting at character 2
//[N2-] All characters starting at character 2
//[N02-9] Characters 2-9, fill from left with zeroes if name shorter than requested (8 in this example): "abc" -> "000000bc"
//[N 2-9] Characters 2-9, fill from left with spaces if name shorter than requested (8 in this example): "abc" -> "      bc"
//[N-8,5] 5 characters starting at the 8-last character (counted from the end of the name)
//[N-8-5] Characters from the 8th-last to the 5th-last character
//[N2--5] Characters from the 2nd to the 5th-last character
//[N-5-] Characters from the 5th-last character to the end of the name
- (void)testNamePlaceholders
{ // [N.....
    {   const auto v = BatchRenamingScheme::ParsePlaceholder_TextExtraction(@"", 0); // [N
        XCTAssert(v);
        if( v ) {
            XCTAssert( v->second == 0 );
            auto a = v->first;
            XCTAssert(a.direct_range &&
                      a.direct_range->location == 0 &&
                      a.direct_range->length == BatchRenamingScheme::Range::max_length());
        }
    }
    
    {   const auto v = BatchRenamingScheme::ParsePlaceholder_TextExtraction(@"364", 0); //[N364]
        XCTAssert(v);
        if( v ) {
            XCTAssert( v->second == 3 );
            auto a = v->first;
            XCTAssert(a.direct_range &&
                      a.direct_range->location == 363 &&
                      a.direct_range->length == 1);
        }
    }

    {   const auto v = BatchRenamingScheme::ParsePlaceholder_TextExtraction(@"364 ", 0); //[N364 ]
        XCTAssert(v);
        if( v ) {
            XCTAssert( v->second == 3 );
            auto a = v->first;
            XCTAssert(a.direct_range &&
                      a.direct_range->location == 363 &&
                      a.direct_range->length == 1);
        }
    }

    {   const auto v = BatchRenamingScheme::ParsePlaceholder_TextExtraction(@"364-365 ", 0); //[N364-365  ]
        XCTAssert(v);
        if( v ) {
            XCTAssert( v->second == 7 );
            auto a = v->first;
            XCTAssert(a.direct_range &&
                      a.direct_range->location == 363 &&
                      a.direct_range->length == 2);
        }
    }
    
    {   const auto v = BatchRenamingScheme::ParsePlaceholder_TextExtraction(@"364,10 ", 0); //[364,10  ]
        XCTAssert(v);
        if( v ) {
            XCTAssert( v->second == 6 );
            auto a = v->first;
            XCTAssert(a.direct_range &&
                      a.direct_range->location == 363 &&
                      a.direct_range->length == 10);
        }
    }

    {   const auto v = BatchRenamingScheme::ParsePlaceholder_TextExtraction(@"-10-", 0); // [N-10-]
        XCTAssert(v);
        if( v ) {
            XCTAssert( v->second == 4 );
            auto a = v->first;
            XCTAssert(!a.direct_range &&
                      a.reverse_range &&
                      a.reverse_range->location == 9 &&
                      a.reverse_range->length == BatchRenamingScheme::Range::max_length());
        }
    }
    
    {   const auto v = BatchRenamingScheme::ParsePlaceholder_TextExtraction(@"-10-2", 0); // [N-10-1]
        XCTAssert(v);
        if( v ) {
            XCTAssert( v->second == 5 );
            auto a = v->first;
            XCTAssert(!a.direct_range &&
                      a.reverse_range &&
                      a.reverse_range->location == 9 &&
                      a.reverse_range->length == 9);
        }
    }
    
    {   const auto v = BatchRenamingScheme::ParsePlaceholder_TextExtraction(@"-10,3", 0); // [N-10-1]
        XCTAssert(v);
        if( v ) {
            XCTAssert( v->second == 5 );
            auto a = v->first;
            XCTAssert(!a.direct_range &&
                      a.reverse_range &&
                      a.reverse_range->location == 9 &&
                      a.reverse_range->length == 3);
        }
    }

    {   const auto v = BatchRenamingScheme::ParsePlaceholder_TextExtraction(@"12--15", 0); // [N4--3]
        XCTAssert(v);
        if( v ) {
            XCTAssert( v->second == 6 );
            auto a = v->first;
            XCTAssert(!a.direct_range &&
                      !a.reverse_range &&
                      a.from_first == 11 &&
                      a.to_last == 14);
        }
    }
}

- (void)testCounterPlaceholders
{ // [C.....

    {   const auto v = BatchRenamingScheme::ParsePlaceholder_Counter(@"-763+3/99:7", 0, 1, 1, 1, 1);
        XCTAssert(v);
        if( v ) {
            XCTAssert( v->second == 11 );
            auto a = v->first;
            XCTAssert(a.start == -763 &&
                      a.step == 3 &&
                      a.stripe == 99 &&
                      a.width == 7);
        }
    }
    
    {   const auto v = BatchRenamingScheme::ParsePlaceholder_Counter(@"-763", 0, 1, 1, 1, 1);
        XCTAssert(v);
        if( v ) {
            XCTAssert( v->second == 4 );
            auto a = v->first;
            XCTAssert(a.start == -763);
        }
    }
    
    {   const auto v = BatchRenamingScheme::ParsePlaceholder_Counter(@"763", 0, 1, 1, 1, 1);
        XCTAssert(v);
        if( v ) {
            XCTAssert( v->second == 3 );
            auto a = v->first;
            XCTAssert(a.start == 763);
        }
    }
    
    {   const auto v = BatchRenamingScheme::ParsePlaceholder_Counter(@"+-13", 0, 1, 1, 1, 1);
        XCTAssert(v);
        if( v ) {
            XCTAssert( v->second == 4 );
            auto a = v->first;
            XCTAssert(a.step == -13);
        }
    }

    {   const auto v = BatchRenamingScheme::ParsePlaceholder_Counter(@"/71", 0, 1, 1, 1, 1);
        XCTAssert(v);
        if( v ) {
            XCTAssert( v->second == 3 );
            auto a = v->first;
            XCTAssert(a.stripe == 71);
        }
    }
    
    {   const auto v = BatchRenamingScheme::ParsePlaceholder_Counter(@":12", 0, 1, 1, 1, 1);
        XCTAssert(v);
        if( v ) {
            XCTAssert( v->second == 3 );
            auto a = v->first;
            XCTAssert(a.width == 12);
        }
    }
}

- (void)testTextExtraction
{
    {   BatchRenamingScheme::TextExtraction te;
        auto r = BatchRenamingScheme::ExtractText(@"1234567890", te);
        XCTAssert( [r isEqualToString:@"1234567890"] );
    }

    {   BatchRenamingScheme::TextExtraction te;
        te.direct_range->location = 4;
        te.direct_range->length = 1;
        auto r = BatchRenamingScheme::ExtractText(@"1234567890", te);
        XCTAssert( [r isEqualToString:@"5"] );
    }

    {   BatchRenamingScheme::TextExtraction te;
        te.direct_range->location = 4;
        auto r = BatchRenamingScheme::ExtractText(@"1234567890", te);
        XCTAssert( [r isEqualToString:@"567890"] );
    }

    {   BatchRenamingScheme::TextExtraction te;
        te.direct_range->location = 10000;
        auto r = BatchRenamingScheme::ExtractText(@"1234567890", te);
        XCTAssert( [r isEqualToString:@""] );
    }

    {   BatchRenamingScheme::TextExtraction te;
        te.direct_range->location = 0;
        te.direct_range->length = 0;
        auto r = BatchRenamingScheme::ExtractText(@"1234567890", te);
        XCTAssert( [r isEqualToString:@""] );
    }

    {   BatchRenamingScheme::TextExtraction te;
        te.direct_range->location = 1;
        te.direct_range->length = 8;
        te.zero_flag = true;
        auto r = BatchRenamingScheme::ExtractText(@"abc", te);
        XCTAssert( [r isEqualToString:@"000000bc"] );
    }

    {   BatchRenamingScheme::TextExtraction te;
        te.direct_range->location = 1;
        te.direct_range->length = 8;
        te.space_flag = true;
        auto r = BatchRenamingScheme::ExtractText(@"abc", te);
        XCTAssert( [r isEqualToString:@"      bc"] );
    }

    {   BatchRenamingScheme::TextExtraction te;
        te.direct_range = std::nullopt;
        te.reverse_range = BatchRenamingScheme::Range(0,1);
        auto r = BatchRenamingScheme::ExtractText(@"abc", te);
        XCTAssert( [r isEqualToString:@"c"] );
    }

    {   BatchRenamingScheme::TextExtraction te;
        te.direct_range = std::nullopt;
        te.reverse_range = BatchRenamingScheme::Range(0, BatchRenamingScheme::Range::max_length());
        auto r = BatchRenamingScheme::ExtractText(@"abc", te);
        XCTAssert( [r isEqualToString:@"c"] );
    }

    {   BatchRenamingScheme::TextExtraction te;
        te.direct_range = std::nullopt;
        te.reverse_range = BatchRenamingScheme::Range(100, BatchRenamingScheme::Range::max_length());
        auto r = BatchRenamingScheme::ExtractText(@"abc", te);
        XCTAssert( [r isEqualToString:@"abc"] );
    }

    {   BatchRenamingScheme::TextExtraction te;
        te.direct_range = std::nullopt;
        te.reverse_range = BatchRenamingScheme::Range(2, 3);
        auto r = BatchRenamingScheme::ExtractText(@"abc", te);
        XCTAssert( [r isEqualToString:@"abc"] );
    }

    {   BatchRenamingScheme::TextExtraction te;
        te.direct_range = std::nullopt;
        te.reverse_range = BatchRenamingScheme::Range(2, 0);
        auto r = BatchRenamingScheme::ExtractText(@"abc", te);
        XCTAssert( [r isEqualToString:@""] );
    }

    {   BatchRenamingScheme::TextExtraction te;
        te.direct_range = std::nullopt;
        te.from_first = 0;
        te.to_last = 0;
        auto r = BatchRenamingScheme::ExtractText(@"abc", te);
        XCTAssert( [r isEqualToString:@"abc"] );
    }
    
    {   BatchRenamingScheme::TextExtraction te;
        te.direct_range = std::nullopt;
        te.from_first = 2;
        te.to_last = 0;
        auto r = BatchRenamingScheme::ExtractText(@"abc", te);
        XCTAssert( [r isEqualToString:@"c"] );
    }

    {   BatchRenamingScheme::TextExtraction te;
        te.direct_range = std::nullopt;
        te.from_first = 3;
        te.to_last = 0;
        auto r = BatchRenamingScheme::ExtractText(@"abc", te);
        XCTAssert( [r isEqualToString:@""] );
    }

    {   BatchRenamingScheme::TextExtraction te;
        te.direct_range = std::nullopt;
        te.from_first = 0;
        te.to_last = 5;
        auto r = BatchRenamingScheme::ExtractText(@"abc", te);
        XCTAssert( [r isEqualToString:@""] );
    }
    
    {   BatchRenamingScheme::TextExtraction te;
        te.direct_range = std::nullopt;
        te.from_first = 100;
        te.to_last = 100;
        auto r = BatchRenamingScheme::ExtractText(@"abc", te);
        XCTAssert( [r isEqualToString:@""] );
    }
    
}


@end
