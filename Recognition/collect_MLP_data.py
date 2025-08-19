import cv2
import mediapipe as mp
import numpy as np
import os
import pandas as pd


gesture_label = 'vertical_V_2'  #  'one', 'two' 와 같은 제스쳐 이름을 바꿔가며 수집
save_path = f'./gesture_data/main_data/transformer/data_{gesture_label}.csv'
os.makedirs(os.path.dirname(save_path), exist_ok=True)
max_num_hands = 1
seq_length = 1  

mp_hands = mp.solutions.hands
mp_drawing = mp.solutions.drawing_utils
hands = mp_hands.Hands(max_num_hands=max_num_hands,
                       min_detection_confidence=0.5,
                       min_tracking_confidence=0.5)

collected_data = []

cap = cv2.VideoCapture(0)

print(f'[INFO] Start collecting "{gesture_label}" gesture data. Press "q" to stop.')

while cap.isOpened():
    ret, img = cap.read()
    if not ret:
        continue

    img = cv2.flip(img, 1)
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    result = hands.process(img_rgb)

    if result.multi_hand_landmarks:
        for res in result.multi_hand_landmarks:
            joint = np.zeros((21, 4))  # 21개 관절의 (x, y, z, visibility)

            for j, lm in enumerate(res.landmark):
                joint[j] = [lm.x, lm.y, lm.z, lm.visibility]

            # 벡터 계산
            v1 = joint[[0,1,2,3,0,5,6,7,0,9,10,11,0,13,14,15,0,17,18,19], :3]
            v2 = joint[[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20], :3]
            v = v2 - v1
            v /= np.linalg.norm(v, axis=1)[:, np.newaxis]

            # 관절 간 각도
            angle = np.arccos(np.einsum('nt,nt->n',
                v[[0,1,2,4,5,6,8,9,10,12,13,14,16,17,18],:],
                v[[1,2,3,5,6,7,9,10,11,13,14,15,17,18,19],:]))

            angle = np.degrees(angle)

            # 데이터 1개 = 관절 위치 + 각도 + 레이블
            d = np.concatenate([joint.flatten(), angle, [gesture_label]])
            collected_data.append(d)

            mp_drawing.draw_landmarks(img, res, mp_hands.HAND_CONNECTIONS)

    cv2.imshow('Collecting Gesture Data', img)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()

collected_data = np.array(collected_data)
df = pd.DataFrame(collected_data)
df.to_csv(save_path, index=False)
print(f'[INFO] Data saved to {save_path}')
