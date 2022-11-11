function createPR() {
    echo "Creating PR on Bitbucket Repo: ${GIT_BASE_URL} -> ${GIT_PROJECT} -> ${GIT_REPO} with details: "
    echo "- Title: ${PR_TITLE}"
    echo "- Description: ${PR_DESCRIPTION}"
    echo "- Source Branch: ${BRANCH_FROM}"
    echo "- Target Branch: ${BRANCH_TO}"
    echo "- Reviewer: ${PR_REVIEWERS}"

    IFS=',' read -r -a REVIEWERS <<< "$PR_REVIEWERS"
    REVIEWER_LIST=""
    for name in "${REVIEWERS[@]}"
    do
        if ! [[ ${REVIEWER_LIST} == "" ]]; then
            REVIEWER_LIST="${REVIEWER_LIST},"
        fi
        REVIEWER_LIST="${REVIEWER_LIST}{\"user\": {\"name\": \"${name}\"}}"
    done
    echo "- Reviewer PR Input: ${REVIEWER_LIST}"

    echo "Calling bitbucket create PR API..."
    response=$(curl --location --request POST "${GIT_BASE_URL}/rest/api/1.0/projects/${GIT_PROJECT}/repos/${GIT_REPO}/pull-requests" \
    --header "Authorization: Bearer ${ACCESS_TOKEN}" \
    --header 'Content-Type: application/json' \
    --data-raw "{
        \"title\": \"${PR_TITLE}\",
        \"description\": \"${PR_DESCRIPTION}\",
        \"state\": \"OPEN\",
        \"open\": true,
        \"closed\": false,
        \"fromRef\": {
            \"id\": \"${BRANCH_FROM}\",
            \"repository\": {
                \"slug\": \"${GIT_REPO}\",
                \"name\": null,
                \"project\": {
                    \"key\": \"${GIT_PROJECT}\"
                }
            }
        },
        \"toRef\": {
            \"id\": \"${BRANCH_TO}\",
            \"repository\": {
                \"slug\": \"${GIT_REPO}\",
                \"name\": null,
                \"project\": {
                    \"key\": \"${GIT_PROJECT}\"
                }
            }
        },
        \"locked\": false,
        \"reviewers\": [
            ${REVIEWER_LIST}
        ]
    }")
    echo "------------------------ ------------------------------"
    echo "$response"
    echo "PR creation complete...."

    PATTERN="$GIT_BASE_URL/projects/$GIT_PROJECT/repos/$GIT_REPO/pull-requests/[0-9]*"
    AUTO_LINT_PR=($(echo "$response" | grep -Eo -1 "$PATTERN"))
    echo "$AUTO_LINT_PR"
}

# ----------------------------------------------------------------------------------------------------
# ----------------------------------------------------------------------------------------------------
# export BRANCH_CONDITION=".*"
# export GIT_BRANCH="develop"

echo "GIT_BRANCH: $GIT_BRANCH"
echo "Preparing Branch..."
CURRENT_BRANCH=$GIT_BRANCH
if [ -z ${CURRENT_BRANCH} ]; then
    echo "Git Branch not provided...."
    exit 0
fi  
echo "Current branch is: ${CURRENT_BRANCH}"

echo "Validating current branch.."
if ! [[ ${CURRENT_BRANCH} =~ ${BRANCH_CONDITION} ]]; then
    echo "This branch does not match condtion: $BRANCH_CONDITION"
    exit 0
fi

if [[ "$CURRENT_BRANCH" == *"autolint"* ]]; then
    echo "This is an auto lint branch..."
    exit 0
fi

FIX_BRANCH="autolint/${CURRENT_BRANCH}"
echo "Fix branch is: ${FIX_BRANCH}"

echo "Updating Existing OR Creating New Commit..."
echo "--------------------------------------------"
echo "Pull latest $CURRENT_BRANCH..."
git pull

echo "Creating OR Checking out (with reverted commits) $FIX_BRANCH Branch..."
git checkout -B $FIX_BRANCH

echo "Adding updated changes..."
git merge $CURRENT_BRANCH
echo "--------------------------------------------"

SWIFT_LINT="./Pods/SwiftLint/swiftlint"
if which "${SWIFT_LINT}" >/dev/null; then
    echo "Linting..."
    echo "--------------------------------------------"
    "${SWIFT_LINT}" --fix
    echo "--------------------------------------------"
else
   echo "warning: SwiftLint not integrated..."
fi

echo "Commiting Changes..."
echo "--------------------------------------------"
git diff-index --quiet HEAD -- || {
    echo "Found changes after lint !"
    git commit -a -m "Applied fixable lint issues using Swift Lint." # -a is to commit only modified and deleted files
    
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Checking the changes are redundant..."
    REMOTE_FIX_EXISTS=$(git ls-remote --heads origin $FIX_BRANCH | wc -l | xargs)
    echo "Remote Fix exists: '$REMOTE_FIX_EXISTS'"

    DIFF_WITH_REMOTE=0
    if [[ $REMOTE_FIX_EXISTS == '1' ]]; 
    then
        echo "Checking diff from remote fix branch..."
        DIFF_WITH_REMOTE=$(git diff --name-only $FIX_BRANCH origin/$FIX_BRANCH | wc -l | xargs)
    fi
    echo "Has diff with local and remote fixes: '$DIFF_WITH_REMOTE'"
    if [[ $REMOTE_FIX_EXISTS == '0' || $DIFF_WITH_REMOTE -gt 0 ]]; 
    then
        echo "Pushing the changes..."
        git push --set-upstream origin $FIX_BRANCH --force

        echo "Creating PR..."
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        PR_TITLE="[Merge With Care] Auto lint of ${CURRENT_BRANCH}"
        PR_DESCRIPTION="Applied auto lint to the branch: ${CURRENT_BRANCH}"
        BRANCH_FROM="${FIX_BRANCH}"
        BRANCH_TO="${CURRENT_BRANCH}"
        
        createPR
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        envman add --key AUTO_LINT_PR --value "$AUTO_LINT_PR"
    else
        echo "Skipping push as duplicate task..."
    fi
}
echo "--------------------------------------------"

git reset --hard
git checkout $CURRENT_BRANCH
git branch -D $FIX_BRANCH