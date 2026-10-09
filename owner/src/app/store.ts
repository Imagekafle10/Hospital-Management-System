import { configureStore } from '@reduxjs/toolkit';
import auth from '../features/authSlice';
import users from '../features/usersSlice';
import hospital from '../features/hospitalSlice';
import pharmacy from '../features/pharmacySlice';

export const store = configureStore({ reducer: { auth, users, hospital, pharmacy } });
export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
