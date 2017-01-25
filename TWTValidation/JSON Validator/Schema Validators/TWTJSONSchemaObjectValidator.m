//
//  TWTJSONSchemaObjectValidator.m
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

#import <TWTValidation/TWTJSONSchemaObjectValidator.h>

#import <TWTValidation/TWTKeyedCollectionValidator.h>
#import <TWTValidation/TWTNumberValidator.h>
#import <TWTValidation/TWTValidationErrors.h>
#import <TWTValidation/TWTValidationLocalization.h>


@interface TWTJSONSchemaObjectValidator ()

@property (nonatomic, strong, readonly) TWTNumberValidator *countValidator;
@property (nonatomic, strong, readonly) NSDictionary *propertyAndValidators;

@end


@implementation TWTJSONSchemaObjectValidator

- (instancetype)initWithMinimumPropertyCount:(NSNumber *)minimumPropertyCount
                        maximumPropertyCount:(NSNumber *)maximumPropertyCount
                        requiredPropertyKeys:(NSSet *)requiredPropertyKeys
                          propertyValidators:(NSArray *)propertyValidators
                   patternPropertyValidators:(NSArray *)patternPropertyValidators
               additionalPropertiesValidator:(TWTValidator *)additionalPropertiesValidator
                        propertyDependencies:(NSDictionary *)propertyDependencies
{
    self = [super init];
    if (self) {
        _minimumPropertyCount = minimumPropertyCount;
        _maximumPropertyCount = maximumPropertyCount;
        _requiredPropertyKeys = [requiredPropertyKeys copy];
        _propertyValidators = [propertyValidators copy];
        _patternPropertyValidators = [patternPropertyValidators copy];
        _additionalPropertiesValidator = [additionalPropertiesValidator copy];
        _propertyDependencies = [propertyDependencies copy];

        //  Make property validators accessible by their key
        NSMutableDictionary *propertyValidatorsByKey = [[NSMutableDictionary alloc] init];
        for (TWTKeyValuePairValidator *pairValidator in propertyValidators) {
            [propertyValidatorsByKey setObject:pairValidator forKey:pairValidator.key];
        }
        _propertyAndValidators = [propertyValidatorsByKey copy];

        if (minimumPropertyCount || maximumPropertyCount) {
            _countValidator = [[TWTNumberValidator alloc] initWithMinimum:minimumPropertyCount maximum:maximumPropertyCount];
        }

    }
    return self;
}


- (instancetype)init
{
    return [self initWithMinimumPropertyCount:nil maximumPropertyCount:nil requiredPropertyKeys:nil propertyValidators:nil patternPropertyValidators:nil
                additionalPropertiesValidator:nil propertyDependencies:nil];
}


- (NSUInteger)hash
{
    return [super hash] ^ self.minimumPropertyCount.hash ^ self.maximumPropertyCount.hash ^ self.requiredPropertyKeys.hash ^ self.propertyValidators.hash ^
        self.patternPropertyValidators.hash ^ self.additionalPropertiesValidator.hash ^ self.propertyDependencies.hash;
}


- (BOOL)isEqual:(id)object
{
    if (![super isEqual:object]) {
        return NO;
    } else if (self == object) {
        return YES;
    }

    typeof(self) other = object;
    return  (other.minimumPropertyCount == self.minimumPropertyCount || (self.minimumPropertyCount && [other.minimumPropertyCount isEqual:self.minimumPropertyCount])) &&
        (other.maximumPropertyCount == self.maximumPropertyCount || (self.maximumPropertyCount && [other.maximumPropertyCount isEqualToNumber:self.maximumPropertyCount])) &&
        (other.requiredPropertyKeys == self.requiredPropertyKeys || [other.requiredPropertyKeys isEqualToSet:self.requiredPropertyKeys]) &&
        (other.propertyValidators == self.propertyValidators || [other.propertyValidators isEqualToArray:self.propertyValidators]) &&
        (other.patternPropertyValidators == self.patternPropertyValidators || [other.patternPropertyValidators isEqualToArray:self.patternPropertyValidators]) &&
        (other.additionalPropertiesValidator == self.additionalPropertiesValidator || [other.additionalPropertiesValidator isEqual:self.additionalPropertiesValidator]) &&
        (other.propertyDependencies == self.propertyDependencies || [other.propertyDependencies isEqualToDictionary:self.propertyDependencies]);
}


- (BOOL)validateValue:(id)value error:(out NSError *__autoreleasing *)outError
{
    if (![super validateValue:value error:outError]) {
        return NO;
    } else if (![value isKindOfClass:[NSDictionary class]]) {
        if (outError) {
            *outError = [NSError twt_validationErrorWithCode:TWTValidationErrorCodeValueHasIncorrectClass
                                            failingValidator:self
                                                       value:value
                                        localizedDescription:TWTLocalizedString(@"TWTJSONSchemaObjectValidator.notJSONObjectError")];
        }
        return NO;
    }

    BOOL countValidated = YES;
    BOOL requiredPropertiesValidated = YES;
    BOOL propertiesValidated = YES;
    BOOL patternPropertiesValidated = YES;
    BOOL additionalPropertiesValidated = YES;
    BOOL dependenciesValidated = YES;

    NSError *countError = nil;
    NSError *requiredPropertiesError = nil;
    NSError *error = nil;
    NSMutableArray *propertiesErrors = outError ? [[NSMutableArray alloc] init] : nil;
    NSMutableArray *dependenciesErrors = outError ? [[NSMutableArray alloc] init] : nil;

    NSSet *keySet = [NSSet setWithArray:[value allKeys]];

    if (self.countValidator) {
        countValidated = [self.countValidator validateValue:@([value count]) error:&countError];
    }

    if (self.requiredPropertyKeys) {
        requiredPropertiesValidated = [self checkRequiredKeys:self.requiredPropertyKeys arePresentInValueKeys:keySet error:&requiredPropertiesError];
    }

    for (NSString *key in value) {
        error = nil;
        BOOL propertyIsDefined = NO;
        id objectForKey = [value objectForKey:key];

        TWTKeyValuePairValidator *propertyValidator = [self.propertyAndValidators objectForKey:key];
        if (propertyValidator) {
            propertyIsDefined = YES;
            if (![propertyValidator validateValue:objectForKey error:outError ? &error : NULL]) {
                propertiesValidated = NO;
                if (error) {
                    [propertiesErrors addObject:error];
                }
            }
        }

        for (TWTKeyValuePairValidator *patternValidator in self.patternPropertyValidators) {
            NSError *regularExpressionError = nil;
            error = nil;
            NSRegularExpression *regularExpression = [NSRegularExpression regularExpressionWithPattern:patternValidator.key options:0 error:&regularExpressionError];

            if (!regularExpressionError) {
                if ([regularExpression numberOfMatchesInString:key options:0 range:NSMakeRange(0, [key length])] > 0) {
                    propertyIsDefined = YES;

                    if (![patternValidator validateValue:objectForKey error:outError ? &error : NULL]) {
                        patternPropertiesValidated = NO;
                        if (error) {
                            [propertiesErrors addObject:error];
                        }
                    };
                }
            } // If regular expression is invalid, no properties will match and thus all instances are valid
        }

        error = nil;
        if (!propertyIsDefined) {
            if (![self.additionalPropertiesValidator validateValue:objectForKey error:outError ? &error : NULL]) {
                additionalPropertiesValidated = NO;
                if (error) {
                    [propertiesErrors addObject:error];
                }
            }
        }

        error = nil;
        id dependency = self.propertyDependencies[key];
        if (dependency) {
            if ([dependency isKindOfClass:[NSSet class]]) {
                dependenciesValidated = [self checkRequiredKeys:dependency arePresentInValueKeys:keySet error:outError ? &error : NULL];
            } else {
                // dependencyValue is a schema validator
                if (![dependency validateValue:value error:outError ? &error : NULL]) {
                    dependenciesValidated = NO;
                    if (error) {
                        [dependenciesErrors addObject:error];
                    }
                }
            }
        }
    }

    BOOL validated = countValidated & requiredPropertiesValidated & propertiesValidated & patternPropertiesValidated & additionalPropertiesValidated & dependenciesValidated;
    if (!validated && outError) {
        NSMutableArray *underlyingErrors = [[NSMutableArray alloc] init];

        if (!countValidated) {
            [underlyingErrors addObject:countError];
        }

        if (!requiredPropertiesValidated) {
            [underlyingErrors addObject:requiredPropertiesError];
        }

        if (!dependenciesValidated) {
            [underlyingErrors addObjectsFromArray:dependenciesErrors];
        }

        if (propertiesErrors.count) {
            [underlyingErrors addObjectsFromArray:propertiesErrors];
        }

        *outError = [NSError twt_validationErrorWithCode:TWTValidationErrorCodeJSONSchemaObjectValidatorError
                                        failingValidator:self
                                                   value:value
                                    localizedDescription:TWTLocalizedString(@"TWTJSONSchemaObjectValidator.validationError")
                                        underlyingErrors:underlyingErrors];
    }

    return validated;
}


- (BOOL)checkRequiredKeys:(NSSet *)requiredKeys arePresentInValueKeys:(NSSet *)valueKeys error:(NSError **)outError
{
    if ([requiredKeys isSubsetOfSet:valueKeys]) {
        return YES;
    }

    if (outError) {
        NSMutableSet *missingKeys = [requiredKeys mutableCopy];
        [missingKeys minusSet:valueKeys];
        NSString *formatDescription = TWTLocalizedString(@"TWTJSONSchemaObjectValidator.requiredPropertyMissing.validationError.format");
        NSString *description = [NSString stringWithFormat:formatDescription, missingKeys];
        *outError = [NSError twt_validationErrorWithCode:TWTValidationErrorCodeJSONSchemaRequiredPropertyNotPresent
                                        failingValidator:self
                                                   value:valueKeys
                                    localizedDescription:description];
    }
    
    return NO;
}


@end
