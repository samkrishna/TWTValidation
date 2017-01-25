//
//  TWTJSONObjectValidatorGenerator.m
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

#import <TWTValidation/TWTJSONObjectValidatorGenerator.h>

#import <TWTValidation/TWTValidation.h>

#import <TWTValidation/TWTJSONSchemaASTCommon.h>
#import <TWTValidation/TWTJSONSchemaParser.h>
#import <TWTValidation/TWTJSONSchemaArrayValidator.h>
#import <TWTValidation/TWTJSONSchemaObjectValidator.h>
#import <TWTValidation/TWTProxyValidator.h>
#import <TWTValidation/TWTValidationLocalization.h>


@interface TWTJSONObjectValidatorGenerator ()

@property (nonatomic, strong, readonly) NSMutableArray *objectStack;

@property (nonatomic, strong) NSMapTable *referenceNodesToProxyValidators;
@property (nonatomic, strong) NSMapTable *referentNodesToValidators;
@property (nonatomic, copy) NSSet *referentNodes;

@end


@implementation TWTJSONObjectValidatorGenerator

- (instancetype)init
{
    self = [super init];
    if (self) {
        _objectStack = [[NSMutableArray alloc] init];
        _referenceNodesToProxyValidators = [NSMapTable strongToStrongObjectsMapTable];
        _referentNodesToValidators = [NSMapTable strongToStrongObjectsMapTable];
    }
    return self;
}


- (TWTJSONObjectValidator *)validatorFromJSONSchema:(NSDictionary *)schema error:(NSError *__autoreleasing *)outError warnings:(NSArray *__autoreleasing *)outWarnings
{
    TWTJSONSchemaParser *parser = [[TWTJSONSchemaParser alloc] initWithJSONSchema:schema];
    TWTJSONSchemaTopLevelASTNode *topLevelNode = [parser parseWithError:outError warnings:outWarnings];
    if (!topLevelNode) {
        return nil;
    }

    // Collect referent nodes
    NSMutableSet *referentNodes = [[NSMutableSet alloc] initWithCapacity:topLevelNode.allReferenceNodes.count];
    for (TWTJSONSchemaReferenceASTNode *referenceNode in topLevelNode.allReferenceNodes) {
        [referentNodes addObject:referenceNode.referentNode];
    }
    self.referentNodes = referentNodes;

    // Generate all validators
    [topLevelNode acceptProcessor:self];

    // If any referenced schemas were remote, create validators for them too
    NSSet *remoteReferentNodes = [self.referentNodes objectsPassingTest:^BOOL(TWTJSONSchemaASTNode *node, BOOL *stop) {
        return [self.referentNodesToValidators objectForKey:node] == nil;
    }];
    for (TWTJSONSchemaASTNode *node in remoteReferentNodes) {
        // Process the nodes so they get saved into the map table
        // Then immediately pop them off the stack; only the top-level validator should be left
        [node acceptProcessor:self];
        [self popCurrentObject];
    }

    // Connect proxy validators to referenced schema
    for (TWTJSONSchemaReferenceASTNode *referenceNode in self.referenceNodesToProxyValidators) {
        TWTProxyValidator *proxyValidator = [self.referenceNodesToProxyValidators objectForKey:referenceNode];
        TWTValidator *validator = [self.referentNodesToValidators objectForKey:referenceNode.referentNode];
        proxyValidator.validator = validator;
    }

    TWTJSONObjectValidator *finalValidator = [self popCurrentObject];

    // Reset properties
    [self.objectStack removeAllObjects];
    [self.referenceNodesToProxyValidators removeAllObjects];
    [self.referentNodesToValidators removeAllObjects];

    return finalValidator;
}


#pragma mark - ASTNodeProcessor protocol methods

- (void)processTopLevelNode:(TWTJSONSchemaTopLevelASTNode *)topLevelNode
{
    [topLevelNode.schema acceptProcessor:self];
}


- (void)processGenericNode:(TWTJSONSchemaGenericASTNode *)genericNode
{
    TWTValidator *commonValidator = [self commonValidatorFromNode:genericNode];
    TWTValidator *typeValidator = nil;

    if ([genericNode.validTypes containsObject:TWTJSONSchemaTypeKeywordBoolean]) {
        typeValidator = [self booleanTypeValidator];
    } else if ([genericNode.validTypes containsObject:TWTJSONSchemaTypeKeywordNull]) {
        typeValidator = [TWTValueValidator valueValidatorWithClass:[NSNull class] allowsNil:NO allowsNull:YES];
    }

    [self pushJSONObjectValidatorWithCommonValidator:commonValidator typeValidator:typeValidator node:genericNode];
}


- (void)processArrayNode:(TWTJSONSchemaArrayASTNode *)arrayNode
{
    TWTValidator *commonValidator = [self commonValidatorFromNode:arrayNode];

    TWTValidator *itemValidator = nil;
    NSArray *indexedItemValidators = nil;
    if (arrayNode.itemSchema) {
        itemValidator = [self validatorFromNode:arrayNode.itemSchema];
    } else {
        indexedItemValidators = [self validatorsFromNodeArray:arrayNode.indexedItemSchemas];
    }

    TWTValidator *additionalItemsValidator = [self validatorFromNode:arrayNode.additionalItemsNode];
    TWTJSONSchemaArrayValidator *typeValidator = [[TWTJSONSchemaArrayValidator alloc] initWithMinimumItemCount:arrayNode.minimumItemCount
                                                                                              maximumItemCount:arrayNode.maximumItemCount
                                                                                           requiresUniqueItems:arrayNode.requiresUniqueItems
                                                                                                 itemValidator:itemValidator
                                                                                         indexedItemValidators:indexedItemValidators
                                                                                      additionalItemsValidator:additionalItemsValidator];

    [self pushJSONObjectValidatorWithCommonValidator:commonValidator typeValidator:typeValidator node:arrayNode];
}


- (void)processNumberNode:(TWTJSONSchemaNumberASTNode *)numberNode
{
    TWTValidator *commonValidator = [self commonValidatorFromNode:numberNode];

    [self pushNewObject:[[NSMutableArray alloc] init]];

    [self addSubvalidator:[self numberTypeValidator]];

    if (numberNode.minimum || numberNode.maximum || numberNode.requireIntegralValue) {
        TWTNumberValidator *validator = [[TWTNumberValidator alloc] initWithMinimum:numberNode.minimum maximum:numberNode.maximum];
        validator.maximumExclusive = numberNode.exclusiveMaximum;
        validator.minimumExclusive = numberNode.exclusiveMinimum;
        validator.requiresIntegralValue = numberNode.requireIntegralValue;
        [self addSubvalidator:validator];
    }

    if (numberNode.multipleOf) {
        double multipleOfValue = numberNode.multipleOf.doubleValue;
        [self addSubvalidator:[[TWTBlockValidator alloc] initWithBlock:^BOOL(id value, NSError *__autoreleasing *outError) {
            if (![value isKindOfClass:[NSNumber class]]) {
                return NO;
            }
            
            double result = [(NSNumber *)value doubleValue] / multipleOfValue;
            return result == trunc(result);
        }]];
    }

    TWTValidator *typeValidator = [self validatorFromSubvalidators];
    [self pushJSONObjectValidatorWithCommonValidator:commonValidator typeValidator:typeValidator node:numberNode];
}


- (void)processObjectNode:(TWTJSONSchemaObjectASTNode *)objectNode
{
    TWTValidator *commonValidator = [self commonValidatorFromNode:objectNode];

    NSArray *properties = [self validatorsFromNodeArray:objectNode.propertySchemas];
    NSArray *patterns = [self validatorsFromNodeArray:objectNode.patternPropertySchemas];
    TWTValidator *additionalPropertiesValidator = [self validatorFromNode:objectNode.additionalPropertiesNode];
    NSDictionary *dependencies = [self dependencyDictionaryFromNodeArray:objectNode.propertyDependencies];
    TWTJSONSchemaObjectValidator *typeValidator = [[TWTJSONSchemaObjectValidator alloc] initWithMinimumPropertyCount:objectNode.minimumPropertyCount
                                                                                                maximumPropertyCount:objectNode.maximumPropertyCount
                                                                                                requiredPropertyKeys:objectNode.requiredPropertyKeys
                                                                                                  propertyValidators:properties
                                                                                           patternPropertyValidators:patterns
                                                                                       additionalPropertiesValidator:additionalPropertiesValidator
                                                                                                propertyDependencies:dependencies];

    [self pushJSONObjectValidatorWithCommonValidator:commonValidator typeValidator:typeValidator node:objectNode];
}


- (void)processStringNode:(TWTJSONSchemaStringASTNode *)stringNode
{
    TWTValidator *commonValidator = [self commonValidatorFromNode:stringNode];
    [self pushNewObject:[[NSMutableArray alloc] init]];

    if (stringNode.maximumLength || stringNode.minimumLength) {
        [self addSubvalidator:[TWTStringValidator stringValidatorWithComposedCharacterMinimumLength:stringNode.minimumLength.unsignedIntegerValue
                                                                                      maximumLength:stringNode.maximumLength ? stringNode.maximumLength.unsignedIntegerValue : NSUIntegerMax]];
    }

    if (stringNode.regularExpression) {
        [self addSubvalidator:[TWTStringValidator stringValidatorWithRegularExpression:stringNode.regularExpression options:0]];
    }

    TWTValidator *typeValidator = [self validatorFromSubvalidators];
    if (!typeValidator) {
        typeValidator = [[TWTStringValidator alloc] init];
    }

    [self pushJSONObjectValidatorWithCommonValidator:commonValidator typeValidator:typeValidator node:stringNode];
}


- (void)processAmbiguousNode:(TWTJSONSchemaAmbiguousASTNode *)ambiguousNode
{
    TWTValidator *commonValidator = [self commonValidatorFromNode:ambiguousNode];
    NSMutableArray *orValidators = [[NSMutableArray alloc] initWithCapacity:ambiguousNode.subNodes.count];
    for (TWTJSONSchemaASTNode *subNode in ambiguousNode.subNodes) {
        [subNode acceptProcessor:self];
        [orValidators addObject:[self popCurrentObject]];
    }

    TWTCompoundValidator *typeValidator = [TWTCompoundValidator orValidatorWithSubvalidators:orValidators];
    [self pushJSONObjectValidatorWithCommonValidator:commonValidator typeValidator:typeValidator node:ambiguousNode];
}


- (void)processBooleanValueNode:(TWTJSONSchemaBooleanValueASTNode *)booleanValueNode
{
    BOOL validates = booleanValueNode.booleanValue;
    [self pushNewObject:[[TWTBlockValidator alloc] initWithBlock:^BOOL(id value, NSError *__autoreleasing *outError) {
        if (!validates && outError) {
            // If in the future a booleanValue node is used for any node properties other than additional items/properties,
            // the error code must be updated
            *outError = [NSError twt_validationErrorWithCode:TWTValidationErrorCodeJSONSchemaAdditionalElementsNotAllowed
                                            failingValidator:nil
                                                       value:nil
                                        localizedDescription:TWTLocalizedString(@"TWTJSONObjectValidator.validationError")];
        }
        return validates;
    }]];
}


- (void)processNamedPropertyNode:(TWTJSONSchemaNamedPropertyASTNode *)propertyNode
{
    [self pushNewObject:[[TWTKeyValuePairValidator alloc] initWithKey:propertyNode.key valueValidator:[self validatorFromNode:propertyNode.valueSchema]]];
}


- (void)processPatternPropertyNode:(TWTJSONSchemaPatternPropertyASTNode *)patternPropertyNode
{
    [self pushNewObject:[[TWTKeyValuePairValidator alloc] initWithKey:patternPropertyNode.key valueValidator:[self validatorFromNode:patternPropertyNode.valueSchema]]];
}


- (void)processDependencyNode:(TWTJSONSchemaDependencyASTNode *)dependencyNode
{
    if (dependencyNode.valueSchema) {
        [dependencyNode.valueSchema acceptProcessor:self];
    } else {
        // node has a property set, which is a set of strings
        [self pushNewObject:dependencyNode.propertySet];
    }
}


- (void)processReferenceNode:(TWTJSONSchemaReferenceASTNode *)referenceNode
{
    TWTValidator *commonValidator = [self commonValidatorFromNode:referenceNode];
    TWTProxyValidator *proxyValidator = [[TWTProxyValidator alloc] init];
    [self.referenceNodesToProxyValidators setObject:proxyValidator forKey:referenceNode];
    [self pushJSONObjectValidatorWithCommonValidator:commonValidator typeValidator:proxyValidator node:referenceNode];
}


#pragma mark - Node-to-validator conversion methods

- (TWTValidator *)commonValidatorFromNode:(TWTJSONSchemaASTNode *)node
{
    [self pushNewObject:[[NSMutableArray alloc] init]];
    if (node.validValues) {
        [self addSubvalidator:[[TWTValueSetValidator alloc] initWithValidValues:node.validValues]];
    }
    [self addSubvalidator:[self compoundValidatorFromNodeArray:node.andSchemas type:TWTCompoundValidatorTypeAnd]];
    [self addSubvalidator:[self compoundValidatorFromNodeArray:node.orSchemas type:TWTCompoundValidatorTypeOr]];
    [self addSubvalidator:[self compoundValidatorFromNodeArray:node.exactlyOneOfSchemas type:TWTCompoundValidatorTypeMutualExclusion]];
    if (node.notSchema) {
        [node.notSchema acceptProcessor:self];
        [self addSubvalidator:[TWTCompoundValidator notValidatorWithSubvalidator:[self popCurrentObject]]];
    }

    if (node.definitions) {
        for (NSString *key in node.definitions) {
            // Processes node so that node/validator pair are stored in map table
            [self validatorFromNode:node.definitions[key]];
        }
    }

    return [self validatorFromSubvalidators];
}


- (TWTValidator *)validatorFromNode:(TWTJSONSchemaASTNode *)node
{
    if (!node) {
        return nil;
    }

    [node acceptProcessor:self];
    return [self popCurrentObject];
}


- (TWTCompoundValidator *)compoundValidatorFromNodeArray:(NSArray *)array type:(TWTCompoundValidatorType)type
{
    if (!array) {
        return nil;
    }

    return [[TWTCompoundValidator alloc] initWithType:type subvalidators:[self validatorsFromNodeArray:array]];
}


- (NSArray *)validatorsFromNodeArray:(NSArray *)array
{
    if (!array) {
        return nil;
    }

    NSMutableArray *validators = [[NSMutableArray alloc] initWithCapacity:array.count];
    for (TWTJSONSchemaASTNode *node in array) {
        [node acceptProcessor:self];
        [validators addObject:[self popCurrentObject]];
    }

    return validators;
}


- (NSDictionary *)dependencyDictionaryFromNodeArray:(NSArray *)array
{
    if (!array) {
        return nil;
    }

    NSMutableDictionary *dependencies = [[NSMutableDictionary alloc] init];
    for (TWTJSONSchemaDependencyASTNode *node in array) {
        [node acceptProcessor:self];
        [dependencies setObject:[self popCurrentObject] forKey:node.key];
    }

    return dependencies;
}


- (TWTValidator *)notValidatorForTypes:(NSSet *)types
{
    NSParameterAssert(types.count);

    NSMutableArray *subvalidators = [[NSMutableArray alloc] initWithCapacity:types.count];

    if ([types containsObject:TWTJSONSchemaTypeKeywordArray]) {
        [subvalidators addObject:[TWTValueValidator valueValidatorWithClass:[NSArray class] allowsNil:NO allowsNull:NO]];
    }
    if ([types containsObject:TWTJSONSchemaTypeKeywordNumber]) {
        [subvalidators addObject:[self numberTypeValidator]];
    }
    if ([types containsObject:TWTJSONSchemaTypeKeywordObject]) {
        [subvalidators addObject:[TWTValueValidator valueValidatorWithClass:[NSDictionary class] allowsNil:NO allowsNull:NO]];
    }
    if ([types containsObject:TWTJSONSchemaTypeKeywordString]) {
        [subvalidators addObject:[TWTValueValidator valueValidatorWithClass:[NSString class] allowsNil:NO allowsNull:NO]];
    }

    // Validators for "integer," "any," "boolean," and "null" should not be needed, because this is only called when the type is not explicit.
    // "Integer" cannot be implied, any keywords can only be interpreted as "number"
    // "Boolean" and "null" will never be implied types because they have no type-specific keywords.
    // If "any" is the implied type, then no type validator exists as the counterpoint to this "not."

    TWTValidator *subvalidator = subvalidators.count > 1 ? [TWTCompoundValidator orValidatorWithSubvalidators:subvalidators] : subvalidators.firstObject;
    return [TWTCompoundValidator notValidatorWithSubvalidator:subvalidator];
}


- (TWTValidator *)numberTypeValidator
{
    return [[TWTBlockValidator alloc] initWithBlock:^BOOL(id value, NSError *__autoreleasing *outError) {
        // Checks that a value is an NSNumber and is NOT encoded as a boolean
        // The NOT is used because a valid value may be encoded as one of several number types (int, double, float, etc.)
        // This enables the TWTJSONObjectValidator to differentiate between numbers and booleans
        BOOL validated = [value isKindOfClass:[NSNumber class]] && strcmp([(NSNumber *)value objCType], @encode(BOOL)) != 0;
        if (!validated && outError) {
            NSString *descriptionFormat = TWTLocalizedString(@"TWTValueValidator.valueHasIncorrectClass.validationError.format");
            NSString *description = nil;
            if ([value isKindOfClass:[NSNumber class]]) {
                description = [NSString stringWithFormat:descriptionFormat, @"boolean", @"number"];
            } else {
                description = [NSString stringWithFormat:descriptionFormat, [value class], [NSNumber class]];
            }

            // Failing validator and value are implemented in TWTBlockValidator
            *outError = [NSError twt_validationErrorWithCode:TWTValidationErrorCodeValueHasIncorrectClass failingValidator:nil value:nil localizedDescription:description];
        }
        return validated;
    }];
}


- (TWTValidator *)booleanTypeValidator
{
    return [[TWTBlockValidator alloc] initWithBlock:^BOOL(id value, NSError *__autoreleasing *outError) {
        // Checks that a value is an NSNumber and is encoded as a boolean
        // This enables the TWTJSONObjectValidator to differentiate between numbers and booleans
        BOOL validated = [value isKindOfClass:[NSNumber class]] && strcmp([(NSNumber *)value objCType], @encode(BOOL)) == 0;
        if (!validated && outError) {
            NSString *descriptionFormat = TWTLocalizedString(@"TWTValueValidator.valueHasIncorrectClass.validationError.format");
            NSString *description = nil;
            if ([value isKindOfClass:[NSNumber class]]) {
                description = [NSString stringWithFormat:descriptionFormat, @"number", @"boolean"];
            } else {
                description = [NSString stringWithFormat:descriptionFormat, [value class], [NSNumber class]];
            }

            // Failing validator and value are implemented in TWTBlockValidator
            *outError = [NSError twt_validationErrorWithCode:TWTValidationErrorCodeValueHasIncorrectClass failingValidator:nil value:nil localizedDescription:description];
        }
        return validated;
    }];
}


# pragma mark - Convenience methods for managing stack

- (void)addSubvalidator:(TWTValidator *)subvalidator
{
    if (subvalidator) {
        [self.currentObject addObject:subvalidator];
    }
}


- (void)pushJSONObjectValidatorWithCommonValidator:(TWTValidator *)commonValidator
                                     typeValidator:(TWTValidator *)typeValidator
                                              node:(TWTJSONSchemaASTNode *)node
{
    TWTValidator *expandedTypeValidator = typeValidator;

    if (!node.isTypeSpecified && typeValidator) {
        // This is equivalent to (!node.isTypeSpecified && ![node.validTypes containsObject:TWTJSONSchemaTypeKeywordAny])
        // because that should be the only scenario where a type validator does not exist
        expandedTypeValidator = [TWTCompoundValidator mutualExclusionValidatorWithSubvalidators:@[ typeValidator, [self notValidatorForTypes:node.validTypes]]];
    }

    TWTJSONObjectValidator *validator = [[TWTJSONObjectValidator alloc] initWithCommonValidator:commonValidator typeValidator:expandedTypeValidator];
    if ([self.referentNodes containsObject:node]) {
        [self.referentNodesToValidators setObject:validator forKey:node];
    }

    [self pushNewObject:validator];
}


- (TWTValidator *)validatorFromSubvalidators
{
    NSArray *subvalidators = [self popCurrentObject];
    switch (subvalidators.count) {
        case 0:
            return nil;
        case 1:
            return subvalidators.firstObject;
        default:
            return [TWTCompoundValidator andValidatorWithSubvalidators:subvalidators];
    }
}


- (void)pushNewObject:(id)object
{
    [self.objectStack addObject:object];
}


- (id)currentObject
{
    return self.objectStack.lastObject;
}


- (id)popCurrentObject
{
    id object = self.currentObject;
    [self.objectStack removeLastObject];
    return object;
}

@end
