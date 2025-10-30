# Debug Thread Issue

## Problem
Messages are appearing in separate threads (`thread_1` and `thread_2`) instead of the same thread.

## Hypothesis
The issue might be in how the UnifiedThreadService determines tradie vs homeowner IDs.

## Test Scenario
Let's say:
- Tradie autoId = 1, userType = 'tradie'
- Homeowner autoId = 2, userType = 'homeowner'

### When Tradie sends message:
- senderId = 1, senderType = 'tradie'
- receiverId = 2, receiverType = 'homeowner'
- UnifiedThreadService determines: tradieId = 1, homeownerId = 2

### When Homeowner sends message:
- senderId = 2, senderType = 'homeowner'  
- receiverId = 1, receiverType = 'tradie'
- UnifiedThreadService determines: tradieId = 1, homeownerId = 2

Both should result in the same tradieId=1, homeownerId=2, so they should find/create the same thread.

## Possible Issues
1. User IDs might be different between apps
2. User types might be inconsistent
3. Race condition in thread creation
4. Existing threads with wrong field names

## Next Steps
1. Add more detailed logging to see exact IDs being used
2. Check Firebase for existing thread documents
3. Verify user ID consistency