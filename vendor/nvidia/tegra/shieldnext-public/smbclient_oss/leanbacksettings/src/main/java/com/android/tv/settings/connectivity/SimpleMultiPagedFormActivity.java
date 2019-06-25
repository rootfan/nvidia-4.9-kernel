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

package com.android.tv.settings.connectivity;

import android.app.Fragment;
import android.os.Bundle;

import com.android.tv.settings.connectivity.setup.PasswordInputWizardFragment;
import com.android.tv.settings.connectivity.setup.SelectFromListWizardFragment;
import com.android.tv.settings.connectivity.setup.TextInputWizardFragment;
import com.android.tv.settings.form.FormPage;
import com.android.tv.settings.form.FormPageResultListener;
import com.android.tv.settings.form.SimpleMultiPagedForm;

import com.android.tv.settings.R;

import java.util.ArrayList;

public abstract class SimpleMultiPagedFormActivity extends SimpleMultiPagedForm implements TextInputWizardFragment.Listener,
        PasswordInputWizardFragment.Listener, SelectFromListWizardFragment.Listener {

    private SimpleFormPageDisplayer mFormPageDisplayer;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        setLayoutProperties(R.layout.setup_auth_activity, R.id.description, R.id.action);
        mFormPageDisplayer = new SimpleFormPageDisplayer(this, getFragmentManager(), R.id.content);
        super.onCreate(savedInstanceState);
    }

    @Override
    protected abstract void displayPage(FormPage formPage, FormPageResultListener listener, boolean forward);

    @Override
    public boolean onPasswordInputComplete(String text, boolean obfuscate) {
        return mFormPageDisplayer.onPasswordInputComplete(text, obfuscate);
    }

    @Override
    public boolean onTextInputComplete(String text) {
        return mFormPageDisplayer.onTextInputComplete(text);
    }

    @Override
    public void onListSelectionComplete(SelectFromListWizardFragment.ListItem listItem) {
        mFormPageDisplayer.onListSelectionComplete(listItem);
    }

    @Override
    public void onListFocusChanged(SelectFromListWizardFragment.ListItem listItem) {
        mFormPageDisplayer.onListFocusChanged(listItem);
    }

    protected Fragment displayPage(SimpleFormPageDisplayer.FormPageInfo formPageInfo, String titleArgument,
                                   String descriptionArgument,
                                   ArrayList<SelectFromListWizardFragment.ListItem> extraChoices,
                                   FormPage previousFormPage,
                                   SimpleFormPageDisplayer.UserActivityListener userActivityListener,
                                   boolean showProgress, FormPage currentFormPage,
                                   FormPageResultListener formPageResultListener, boolean forward, boolean emptyAllowed, String prefill) {

        return mFormPageDisplayer.displayPage(formPageInfo, titleArgument, descriptionArgument, extraChoices,
                previousFormPage, userActivityListener, showProgress,
                currentFormPage, formPageResultListener, forward, emptyAllowed, prefill);
    }

    protected void displayFragment(Fragment fragment, boolean forward) {
        mFormPageDisplayer.displayFragment(fragment, forward);
    }
}
