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

package com.android.tv.settings.connectivity.setup;

import android.app.Fragment;
import android.graphics.drawable.AnimationDrawable;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import com.android.tv.settings.R;

/**
 * Displays a UI for showing a message with an optional progress indicator in
 * the "wizard" style.
 */
public class MessageWizardFragment extends Fragment {

    private static final String EXTRA_TITLE = "title";
    private static final String EXTRA_DESCRIPTION = "description";
    private static final String EXTRA_SHOW_PROGRESS_INDICATOR = "show_progress_indicator";

    public static MessageWizardFragment newInstance(String title, String desc, boolean showProgressIndicator) {
        MessageWizardFragment fragment = new MessageWizardFragment();
        Bundle args = new Bundle();
        addArguments(args, title, desc, showProgressIndicator);
        fragment.setArguments(args);
        return fragment;
    }

    public static void addArguments(Bundle args, String title, String desc, boolean showProgressIndicator) {
        args.putString(EXTRA_TITLE, title);
        args.putString(EXTRA_DESCRIPTION, desc);
        args.putBoolean(EXTRA_SHOW_PROGRESS_INDICATOR, showProgressIndicator);
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle icicle) {
        final View view = inflater.inflate(R.layout.setup_activity_progress, container, false);

        final ImageView progressView = (ImageView) view.findViewById(R.id.progress);
        final TextView titleView = (TextView) view.findViewById(R.id.status_text);
        final TextView descView = (TextView) view.findViewById(R.id.desc_text);
        final ImageView iconview = (ImageView) view.findViewById(R.id.icon_view);

        Bundle args = getArguments();
        String title = args.getString(EXTRA_TITLE);
        String description = args.getString(EXTRA_DESCRIPTION);
        boolean showProgressIndicator = args.getBoolean(EXTRA_SHOW_PROGRESS_INDICATOR);

        if (title != null) {
            titleView.setText(title);
            titleView.setVisibility(View.VISIBLE);
        } else {
            titleView.setVisibility(View.GONE);
        }


        if (description != null) {
            descView.setText(description);
            descView.setVisibility(View.VISIBLE);
            iconview.setVisibility(View.VISIBLE);
        } else {
            descView.setVisibility(View.GONE);
            iconview.setVisibility(View.GONE);
        }

        if (showProgressIndicator) {
            progressView.setVisibility(View.VISIBLE);
            ((AnimationDrawable) progressView.getDrawable()).start();
        } else {
            progressView.setVisibility(View.GONE);
        }

        return view;
    }

    @Override
    public void onResume() {
        super.onResume();
    }
}
