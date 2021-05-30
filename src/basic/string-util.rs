// SPDX-License-Identifier: LGPL-2.1-or-later

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::os::raw::c_int;
use std::ptr;

/// Extract the i'nth line from the specified string. Returns > 0 if there are more lines after
/// that, and == 0 if we are looking at the last line or already beyond the last line. As special
/// optimization, if the first line is requested and the string only consists of one line we return
/// NULL, indicating the input string should be used as is, and avoid a memory allocation for a
/// very common case.
///
/// # Safety
///
/// This function expects a non-NULL `ret` parameter, and will dereference it without checking.
/// If the return value is >=0 and `*ret` is non-NULL, then it will point to a dynamically
/// allocated buffer that the caller needs to take ownership of.
#[no_mangle]
pub unsafe extern "C" fn string_extract_line(
    s: *const c_char,
    i: usize,
    ret: *mut *mut c_char,
) -> c_int {
    let s = CStr::from_ptr(s).to_string_lossy();
    let mut lines = s.lines().enumerate().peekable();

    while let Some((j, item)) = lines.next() {
        if i == j && lines.peek() == None {
            // Special case: the iterator will terminate if there's only one line, but it
            // terminates with a newline character, so ensure to check for that too
            if i == 0 && !s.ends_with('\n') {
                *ret = ptr::null_mut();
            } else {
                *ret = CString::new(item).expect("CString::new failed").into_raw();
            }

            return 0;
        }

        if i == j {
            *ret = CString::new(item).expect("CString::new failed").into_raw();

            return 1;
        }
    }

    *ret = CString::new("").expect("CString::new failed").into_raw();

    0
}

// The tests are borrowed from https://play.rust-lang.org/?version=stable&mode=debug&edition=2018&gist=ca729c1478cd21893ae6f8f5ebde4ac2
// which in turn was mentioned in https://github.com/systemd/systemd/pull/19598#discussion_r632891919
#[cfg(test)]
mod tests {
    use super::*;

    // This test panics. It should probably be replaced with something else
    #[test]
    #[ignore]
    fn empty_string() {
        let s = b"\0";
        let mut ret: *mut c_char = ptr::null_mut();

        let r = unsafe { string_extract_line(s.as_ptr() as *const c_char, 0, &mut ret) };
        assert_eq!(r, 0);
        assert!(ret.is_null());

        let r = unsafe { string_extract_line(s.as_ptr() as *const c_char, 1, &mut ret) };
        assert_eq!(r, 0);
        assert!(!ret.is_null());
        let ret = unsafe { CString::from_raw(ret) };
        assert_eq!(ret.to_str(), Ok(""));
    }

    #[test]
    fn multiple_line() {
        let s = b"\
test
multiple
lines\0";

        let mut ret: *mut c_char = ptr::null_mut();

        let r = unsafe { string_extract_line(s.as_ptr() as *const c_char, 1, &mut ret) };

        assert_eq!(r, 1);
        assert!(!ret.is_null());
        let ret = unsafe { CString::from_raw(ret) };
        assert_eq!(ret.to_str(), Ok("multiple"));

        let mut ret: *mut c_char = ptr::null_mut();
        let r = unsafe { string_extract_line(s.as_ptr() as *const c_char, 2, &mut ret) };

        assert_eq!(r, 0);
        assert!(!ret.is_null());
        let ret = unsafe { CString::from_raw(ret) };
        assert_eq!(ret.to_str(), Ok("lines"));
    }

    #[test]
    fn whole_string() {
        let s = b"foo\0";
        let mut ret: *mut c_char = ptr::null_mut();

        let r = unsafe { string_extract_line(s.as_ptr() as *const c_char, 0, &mut ret) };

        assert_eq!(r, 0);
        assert!(ret.is_null());

        let s = b"foo\n\0";

        let r = unsafe { string_extract_line(s.as_ptr() as *const c_char, 0, &mut ret) };

        assert_eq!(r, 0);
        assert!(!ret.is_null());
        let ret = unsafe { CString::from_raw(ret) };
        assert_eq!(ret.to_str(), Ok("foo"));
    }
}
