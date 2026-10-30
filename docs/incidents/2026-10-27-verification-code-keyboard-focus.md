# 2026-10-27 Verification-code keyboard focus

## Problem / environment

In the Linux client, entering a verification code character by character could
lose the caret/focus, while pasting the whole code worked. Email delivery was a
separate path. The regression reproduces with an account dialog behind the
verification dialog on the Linux widget-test target.

## Root cause and fix

`CustomAlertDialog.build` created a new FocusScopeNode and scheduled an explicit
focus request on every rebuild. Rebuilding the underlying dialog could steal
focus; TextField restoration could select existing input and replace it with
the next character. Let FocusScope retain its node, remove the repeated deferred
request and use its callback node for Tab traversal.

Only the shared dialog focus lifecycle changes. There is no authentication,
input-formatter, clipboard, remote-keyboard or server change. The tests verify
six successive edits and paste while the underlying dialog rebuilds, plus
submit/cancel/Tab navigation. The unfixed regression selected range 0..2 where
a collapsed caret at 2 was expected.

## Verification / rollback

The two widget tests in `flutter/test/verification_code_input_test.dart` pass.
They are included again in the 2026-10-30 stable-SDK publication checks. Widget
tests do not establish all compositor/input-method behavior.

Revert the scoped FocusScope change to roll back. Account credentials, server
configuration and saved remote connections need no migration.
