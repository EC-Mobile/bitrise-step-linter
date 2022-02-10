# bitrise step linter

Run Swiftlint auto fix and create a PR.

## Required Params and Sample Values

You need to pass these param, all are required:

### Secure Params:

- ACCESS_TOKEN:                                     You can create in your bitbucket account settings.

### Normal Params;
- GIT_BASE_URL:                                     https://git.mydomain.com
- GIT_PROJECT:                                      My-MOBILE
- GIT_REPO:                                         app-ios
- PR_REVIEWERS:                                     user.name1,user.name2
- BRANCH_CONDITION:                                 [feature/*|bugfix/*|refactor/*]  (Regular Expression)

## Outputs
- AUTO_LINT_PR:                                     https://git.mydomain.com/projects/MY-MOBILE/repos/app-ios/pull-requests/123

## How to use this Step

Add this in your bitrise.yml file and replace proper variables:

```
- git::https://github.com/EC-Mobile/bitrise-step-linter.git@main:
    title: Swift Linter
    inputs:
    - ACCESS_TOKEN: <Variable>
    - GIT_BASE_URL: <Bitbucket Domain>
    - GIT_PROJECT: <Project>
    - GIT_REPO: <Repo>
    - PR_REVIEWERS: <Variable>
    - BRANCH_CONDITION: .*
```