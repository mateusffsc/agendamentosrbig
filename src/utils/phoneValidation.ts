/**
 * Utility functions for Brazilian phone number validation and formatting
 */

/**
 * Formats a phone number to Brazilian format (31) 97322-3898
 * @param value - Raw phone number string
 * @returns Formatted phone number
 */
export const formatPhoneNumber = (value: string): string => {
  // Remove all non-digit characters
  const numbers = value.replace(/\D/g, '')
  
  // Limit to 11 digits (Brazilian mobile format: 11 digits)
  const limited = numbers.slice(0, 11)
  
  // Apply formatting (31) 97322-3898
  if (limited.length <= 2) {
    return limited
  } else if (limited.length <= 7) {
    return `(${limited.slice(0, 2)}) ${limited.slice(2)}`
  } else {
    return `(${limited.slice(0, 2)}) ${limited.slice(2, 7)}-${limited.slice(7)}`
  }
}

/**
 * Validates if a phone number is in the correct Brazilian format
 * @param phone - Phone number string to validate
 * @returns true if valid, false otherwise
 */
export const isValidBrazilianPhone = (phone: string): boolean => {
  // Brazilian mobile phone regex: (XX) 9XXXX-XXXX
  const brazilianPhoneRegex = /^\(\d{2}\) 9\d{4}-\d{4}$/
  return brazilianPhoneRegex.test(phone)
}

/**
 * Extracts only digits from a formatted phone number
 * @param formattedPhone - Formatted phone number string
 * @returns Digits only string
 */
export const getPhoneDigits = (formattedPhone: string): string => {
  return formattedPhone.replace(/\D/g, '')
}

/**
 * Validates if the phone number has the correct number of digits
 * @param phone - Phone number string (formatted or unformatted)
 * @returns true if has 11 digits, false otherwise
 */
export const hasCorrectDigitCount = (phone: string): boolean => {
  const digits = getPhoneDigits(phone)
  return digits.length === 11
}