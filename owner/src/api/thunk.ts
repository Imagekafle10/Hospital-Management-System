import { createAsyncThunk } from '@reduxjs/toolkit';

// Thin wrapper so every thunk is a real createAsyncThunk that rejects with a readable string.
export function makeThunk<R, A = void>(type: string, fn: (arg: A) => Promise<R>) {
  return createAsyncThunk<R, A, { rejectValue: string }>(type, async (arg, { rejectWithValue }) => {
    try {
      return await fn(arg);
    } catch (e) {
      return rejectWithValue(e instanceof Error ? e.message : 'Something went wrong');
    }
  });
}
