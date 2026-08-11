# Implementation Plan - Completing App Functionality

This plan aims to make all remaining "placeholder" features fully functional by integrating them with Firebase Firestore.

## User Review Required

> [!IMPORTANT]
> - **Messaging**: I will implement a global mess chat. All members of a mess will see the same messages.
> - **Meal Planning**: Managers will be able to set the "Menu of the week", which members can then view.
> - **Real Data**: I will replace all remaining "Sample Data" with live database streams.

## Proposed Changes

### Models
#### [NEW] [message_model.dart](file:///D:/all code/Flutter all projects/mess_management/lib/models/message_model.dart)
- Define `MessageModel` with `id`, `senderId`, `senderName`, `text`, `imageUrl`, `timestamp`.

#### [NEW] [meal_plan_model.dart](file:///D:/all code/Flutter all projects/mess_management/lib/models/meal_plan_model.dart)
- Define `MealPlanModel` to store the menu for each day of the week.

### Services
#### [MODIFY] [database_service.dart](file:///D:/all code/Flutter all projects/mess_management/lib/services/database_service.dart)
- **Chat**:
    - `sendMessage(String messId, MessageModel message)`
    - `getMessages(String messId)`: Stream of messages.
- **Meal Planning**:
    - `updateMealPlan(String messId, Map<String, dynamic> plan)`
    - `getMealPlan(String messId)`: Stream of the current plan.
- **History Analytics**:
    - Ensure `getMessMonthlyMeals` provides enough data for the Admin History view.

### Views
#### [MODIFY] [manager_messaging.dart](file:///D:/all code/Flutter all projects/mess_management/lib/views/manager/manager_messaging.dart) & [masseging.dart](file:///D:/all code/Flutter all projects/mess_management/lib/views/member/masseging.dart)
- Connect to `DatabaseService` messages stream.
- Implement real "Send" logic that writes to Firestore.
- Add "Sender Name" to bubbles.

#### [MODIFY] [add_meal_planning.dart](file:///D:/all code/Flutter all projects/mess_management/lib/views/manager/add_meal_planning.dart)
- Implement logic to save the edited plan to Firestore.

#### [MODIFY] [meal_planning.dart](file:///D:/all code/Flutter all projects/mess_management/lib/views/member/meal_planning.dart)
- Remove sample data and listen to the mess meal plan stream.

#### [MODIFY] [history_admin.dart](file:///D:/all code/Flutter all projects/mess_management/lib/views/manager/history_admin.dart)
- Replace sample logic with actual calculations using the `meals` and `messes` collections.

## Verification Plan

### Manual Verification
1.  **Chat**: Open chat on two different devices/emulators. Send a message on one and verify it appears instantly on the other.
2.  **Meal Planning**: As a Manager, update the menu. As a Member, verify the menu updates on the "Meal Planning" page.
3.  **Analytics**: Verify that the Admin History correctly sums up all meals and guest meals for the entire mess.
