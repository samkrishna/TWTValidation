//
//  TWTValidationErrors.m
//  TWTValidation
//
//  Created by Prachi Gauriar on 3/29/2014.
//  Copyright (c) 2015 Ticketmaster Entertainment, Inc. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

//
//  NSError+TWTValidation.m
//  SKValidation
//
//  Created by Sam Krishna on 1/16/20.
//  Copyright © 2020 Ticketmaster Entertainment, Inc. All rights reserved.
//

#import "NSError+TWTValidation.h"

#pragma mark Constants

NSString *const TWTValidationErrorDomain = @"TWT Validation Error Domain";

NSString *const TWTValidationFailingValidatorKey = @"TWT Validation Failing Validator";
NSString *const TWTValidationValidatedValueKey = @"TWT Validation Validated Value";
NSString *const TWTValidationUnderlyingErrorsKey = @"TWT Validation Underlying Errors";
NSString *const TWTValidationUnderlyingErrorsByKeyKey = @"TWT Validation Underlying Errors By Key";

NSString *const TWTValidationCountValidationErrorKey = @"TWT Validation Count Validation Error";
NSString *const TWTValidationElementValidationErrorsKey = @"TWT Validation Element Validation Errors";

NSString *const TWTValidationKeyValidationErrorsKey = @"TWT Validation Key Validation Errors";
NSString *const TWTValidationValueValidationErrorsKey = @"TWT Validation Value Validation Errors";
NSString *const TWTValidationKeyValuePairValidationErrorsKey = @"TWT Validation Key Value Pair Validation Errors";

NSString *const TWTJSONSchemaParserErrorDomain = @"TWT JSON Schema Parser Error Domain";
NSString *const TWTJSONSchemaParserInvalidObjectKey = @"TWT JSON Schema Parser Invalid Object";

@implementation NSError (TWTValidation)

@end
