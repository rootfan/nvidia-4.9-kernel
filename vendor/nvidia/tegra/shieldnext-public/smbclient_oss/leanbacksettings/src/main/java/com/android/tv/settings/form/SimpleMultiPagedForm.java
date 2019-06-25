/*
 * Copyright (C) 2014 The Android Open Source Project
 * Copyright (C) 2016 NVIDIA Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

package com.android.tv.settings.form;

import android.content.Intent;
import android.os.Bundle;
import android.app.Activity;
import android.util.Log;
import android.view.View;

import com.android.tv.settings.R;

import java.util.ArrayList;
import java.util.Stack;

public abstract class SimpleMultiPagedForm extends Activity implements FormPageResultListener {

    private static final String TAG = SimpleMultiPagedForm.class.getSimpleName();
    protected final ArrayList<FormPage> mFormPages = new ArrayList<FormPage>();
    private final Stack<Object> mFlowStack = new Stack<Object>();
    private static final int INTENT_FORM_PAGE_DATA_REQUEST = 1;
    private int mLayoutResId = R.layout.activity_simple_multi_paged_form;
    private View mContent;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        performNextStep();
        super.onCreate(savedInstanceState);
        mContent = getLayoutInflater().inflate(mLayoutResId, null);
        setContentView(mContent);
    }

    public void onBundlePageResult(FormPage page, Bundle bundleResults) {
        page.complete(bundleResults);
        if (!onPageComplete(page)) {
            displayCurrentStep(false);
        } else {
            performNextStep();
        }
    }

    public void setLayoutProperties(int layoutResId, int contentAreaId, int actionAreaId) {
        mLayoutResId = layoutResId;
    }

    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == INTENT_FORM_PAGE_DATA_REQUEST) {
            if (resultCode == RESULT_OK) {
                Object currentLocation = mFlowStack.peek();
                if (currentLocation instanceof FormPage) {
                    FormPage page = (FormPage) currentLocation;
                    Bundle results = data == null ? null : data.getExtras();
                    if (data == null) {
                        Log.w(TAG, "Intent result was null!");
                    } else if (results == null) {
                        Log.w(TAG, "Intent result extras were null!");
                    } else if (!results.containsKey(FormPage.DATA_KEY_SUMMARY_STRING)) {
                        Log.w(TAG, "Intent result extras didn't have the result summary key!");
                    }
                    onBundlePageResult(page, results);
                } else {
                    Log.e(TAG, "Our current location wasn't on the top of the stack!");
                }
            } else {
                onBackPressed();
            }
        }
    }

    @Override
    public void onBackPressed() {
        if (mFlowStack.size() < 1) {
            setResult(RESULT_CANCELED);
            finish();
            return;
        }

        // Pop the current location off the stack.
        mFlowStack.pop();

        // Peek at the previous location on the stack.
        Object lastLocation = mFlowStack.isEmpty() ? null : mFlowStack.peek();

        if (lastLocation instanceof FormPage && !mFormPages.contains(lastLocation)) {
            onBackPressed();
        } else {
            displayCurrentStep(false);
            if (mFlowStack.isEmpty()) {
                setResult(RESULT_CANCELED);
                finish();
            }
        }
    }

    protected void displayFormResults(ArrayList<FormPage> formPages, FormResultListener listener) {

    }

    private void performNextStep() {

        // First see if there are any incomplete form pages.
        FormPage nextIncompleteStep = findNextIncompleteStep();

        // If all the pages we have are complete, display the results.
        if (nextIncompleteStep == null) {
            mFlowStack.push(this);
        } else {
            mFlowStack.push(nextIncompleteStep);
        }
        displayCurrentStep(true);
    }
    private FormPage findNextIncompleteStep() {
        for (int i = 0, size = mFormPages.size(); i < size; i++) {
            FormPage formPage = mFormPages.get(i);
            if (!formPage.isComplete()) {
                return formPage;
            }
        }
        return null;
    }

    protected void undisplayCurrentPage() {

    }

    private void displayCurrentStep(boolean forward) {
        if (!mFlowStack.isEmpty()) {
            Object currentLocation = mFlowStack.peek();
            if (currentLocation instanceof FormPage) {
                FormPage page = (FormPage) currentLocation;
                if (page.getType() == FormPage.Type.INTENT) {
                    startActivityForResult(page.getIntent(), INTENT_FORM_PAGE_DATA_REQUEST);
                }
                displayPage(page, this, forward);
            } else {
                // If this is an unexpected type, something went wrong, finish as
                // cancelled.
                //setResult(RESULT_CANCELED);
                //finish();
            }
        } else {
                undisplayCurrentPage();
        }
    }

    protected void addPage(FormPage formPage) {
        mFormPages.add(formPage);
    }

    protected void removePage(FormPage formPage) {
        mFormPages.remove(formPage);
    }

    protected void clear() {
        mFormPages.clear();
    }

    protected void clearAfter(FormPage formPage) {
        int indexOfPage = mFormPages.indexOf(formPage);
        if (indexOfPage >= 0) {
            for (int i = mFormPages.size() - 1; i > indexOfPage; i--) {
                mFormPages.remove(i);
            }
        }
    }

    protected abstract void displayPage(FormPage formPage, FormPageResultListener listener,
                               boolean forward);

    protected abstract boolean onPageComplete(FormPage formPage);
}
