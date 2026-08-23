use std::{convert::Infallible, str::FromStr};

/// A simple wrapper around `bool` that treats certain values as falsey when
/// parsing from a string.
#[derive(Clone, Copy, Debug)]
pub struct FalseyBool(pub bool);

impl FromStr for FalseyBool {
    type Err = Infallible;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let has_no = ["n", "no", "f", "false", "off", "0"]
            .into_iter()
            .any(|no| s.eq_ignore_ascii_case(no));
        Ok(Self(!has_no))
    }
}
