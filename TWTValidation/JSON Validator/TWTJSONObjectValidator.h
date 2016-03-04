//
//  TWTJSONObjectValidator.h
//  TWTValidation
//
//  Created by Jill Cohen on 1/14/15.
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

#import <TWTValidation/TWTValidator.h>

/*!
 TWTJSONObjectValidators validate JSON objects against a schema that describes the expected structure of the object. They are useful when validating responses from an API before mapping the response into a model object.
 
 Schemas are expected to be in the format described by http://json-schema.org and http://json-schema.org/latest/json-schema-validation.html
 
 This class is not meant to be subclassed.
 */
@interface TWTJSONObjectValidator : TWTValidator

@property (nonatomic, copy, readonly) NSDictionary *schema;

+ (TWTJSONObjectValidator *)validatorWithJSONSchema:(NSDictionary *)schema
                                              error:(NSError *__autoreleasing *)outError
                                           warnings:(NSArray *__autoreleasing *)outWarnings;

@end
