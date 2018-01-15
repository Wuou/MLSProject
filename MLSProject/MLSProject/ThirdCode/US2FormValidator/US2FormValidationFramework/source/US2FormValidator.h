
#if __has_include(<US2FormValidator/US2FormValidator.h>)
// Base
#import <US2FormValidator/US2Condition.h>
#import <US2FormValidator/US2Validator.h>
#import <US2FormValidator/US2ValidatorTextField.h>
#import <US2FormValidator/US2ValidatorTextView.h>
#import <US2FormValidator/US2Form.h>
#import <US2FormValidator/US2ValidatorUIProtocol.h>
#import <US2FormValidator/US2ValidatorUIDelegate.h>

// Conditions
#import <US2FormValidator/US2ConditionAlphabetic.h>
#import <US2FormValidator/US2ConditionAlphanumeric.h>
#import <US2FormValidator/US2ConditionCollection.h>
#import <US2FormValidator/US2ConditionEmail.h>
#import <US2FormValidator/US2ConditionNumeric.h>
#import <US2FormValidator/US2ConditionPostcodeUK.h>
#import <US2FormValidator/US2ConditionRange.h>
#import <US2FormValidator/US2ConditionURL.h>
#import <US2FormValidator/US2ConditionShorthandURL.h>
#import <US2FormValidator/US2ConditionPasswordStrength.h>
#import <US2FormValidator/US2ConditionPresent.h>
#import <US2FormValidator/US2ConditionOr.h>
#import <US2FormValidator/US2ConditionAnd.h>
#import <US2FormValidator/US2ConditionNot.h>

// Validators
#import <US2FormValidator/US2ValidatorAlphabetic.h>
#import <US2FormValidator/US2ValidatorAlphanumeric.h>
#import <US2FormValidator/US2ValidatorEmail.h>
#import <US2FormValidator/US2ValidatorNumeric.h>
#import <US2FormValidator/US2ValidatorPasswordStrength.h>
#import <US2FormValidator/US2ValidatorPostcodeUK.h>
#import <US2FormValidator/US2ValidatorRange.h>
#import <US2FormValidator/US2ValidatorURL.h>
#import <US2FormValidator/US2ValidatorShorthandURL.h>
#import <US2FormValidator/US2ValidatorComposite.h>
#import <US2FormValidator/US2ValidatorPresent.h>
#else
// Base
#import "US2Condition.h"
#import "US2Validator.h"
#import "US2ValidatorTextField.h"
#import "US2ValidatorTextView.h"
#import "US2Form.h"
#import "US2ValidatorUIProtocol.h"
#import "US2ValidatorUIDelegate.h"

// Conditions
#import "US2ConditionAlphabetic.h"
#import "US2ConditionAlphanumeric.h"
#import "US2ConditionCollection.h"
#import "US2ConditionEmail.h"
#import "US2ConditionNumeric.h"
#import "US2ConditionPostcodeUK.h"
#import "US2ConditionRange.h"
#import "US2ConditionURL.h"
#import "US2ConditionShorthandURL.h"
#import "US2ConditionPasswordStrength.h"
#import "US2ConditionPresent.h"
#import "US2ConditionOr.h"
#import "US2ConditionAnd.h"
#import "US2ConditionNot.h"

// Validators
#import "US2ValidatorAlphabetic.h"
#import "US2ValidatorAlphanumeric.h"
#import "US2ValidatorEmail.h"
#import "US2ValidatorNumeric.h"
#import "US2ValidatorPasswordStrength.h"
#import "US2ValidatorPostcodeUK.h"
#import "US2ValidatorRange.h"
#import "US2ValidatorURL.h"
#import "US2ValidatorShorthandURL.h"
#import "US2ValidatorComposite.h"
#import "US2ValidatorPresent.h"
#endif
