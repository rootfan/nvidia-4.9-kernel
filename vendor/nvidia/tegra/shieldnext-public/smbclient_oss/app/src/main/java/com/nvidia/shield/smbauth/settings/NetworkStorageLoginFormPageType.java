/*=====================================================================
  Copyright (C) NVIDIA, 2018

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, see <http://www.gnu.org/licenses/>.
  =====================================================================*/

package com.nvidia.shield.smbauth.settings;


import android.content.Context;
import android.content.Intent;

import com.android.tv.settings.connectivity.SimpleFormPageDisplayer;
import com.android.tv.settings.connectivity.setup.SelectFromListWizardFragment;
import com.android.tv.settings.connectivity.setup.TextInputWizardFragment;
import com.android.tv.settings.form.FormPage;
import com.nvidia.shield.smbauth.R;

import java.util.ArrayList;

public enum NetworkStorageLoginFormPageType implements SimpleFormPageDisplayer.FormPageInfo {
    CHOOSE_LOGIN(SimpleFormPageDisplayer.DISPLAY_TYPE_LIST_CHOICE, R.string.network_storage_login_title, R.string.network_storage_login_dscription, new int[] {R.string.network_storage_login_as_user, R.string.network_storage_login_as_guest}),
    ENTER_ADDRESS(SimpleFormPageDisplayer.DISPLAY_TYPE_TEXT_INPUT, R.string.network_storage_login_enter_address_title, R.string.network_storage_login_example_address_format, TextInputWizardFragment.INPUT_TYPE_NO_SUGGESTIONS),
    ENTER_DOMAIN(SimpleFormPageDisplayer.DISPLAY_TYPE_PREFILLED_TEXT_INPUT, R.string.network_storage_login_enter_domain_title, 0, TextInputWizardFragment.INPUT_TYPE_NO_SUGGESTIONS),
    ENTER_USERNAME(SimpleFormPageDisplayer.DISPLAY_TYPE_TEXT_INPUT, R.string.network_storage_login_enter_username_title, 0, TextInputWizardFragment.INPUT_TYPE_NO_SUGGESTIONS),
    ENTER_PASSWORD(SimpleFormPageDisplayer.DISPLAY_TYPE_PASSWORD_INPUT, R.string.network_storage_login_enter_password_title, 0, 0);

    private final int mDisplayType;
    private final int mTitleResource;
    private final int mDescriptionResource;
    private final int mInputType;
    private final int[] mDefaultListItemTitles;
    private final int[] mDefaultListItemIcons;

    private NetworkStorageLoginFormPageType(int displayType, int titleResource, int descriptionResource) {
        this(displayType, titleResource, descriptionResource, TextInputWizardFragment.INPUT_TYPE_NORMAL);
    }

    private NetworkStorageLoginFormPageType(int displayType, int titleResource, int descriptionResource,
                                            int textType) {
        mDisplayType = displayType;
        mTitleResource = titleResource;
        mDescriptionResource = descriptionResource;
        mInputType = textType;
        mDefaultListItemIcons = null;
        mDefaultListItemTitles = null;
    }

    NetworkStorageLoginFormPageType(int displayType, int titleResource, int descriptionResource,
                                    int[] defaultListItemTitles) {
        this(displayType, titleResource, descriptionResource, defaultListItemTitles, null);
    }

    NetworkStorageLoginFormPageType(int displayType, int titleResource, int descriptionResource,
                                    int[] defaultListItemTitles, int[] defaultListItemIcons) {
        mDisplayType = displayType;
        mTitleResource = titleResource;
        mDescriptionResource = descriptionResource;
        mInputType = TextInputWizardFragment.INPUT_TYPE_NORMAL;
        mDefaultListItemTitles = defaultListItemTitles;
        mDefaultListItemIcons = defaultListItemIcons;
        if (mDefaultListItemTitles != null && mDefaultListItemIcons != null
                && mDefaultListItemTitles.length != mDefaultListItemIcons.length) {
            throw new IllegalArgumentException("Form page type " + name()
                    + " had title and icon arrays that we'ren't the same length! "
                    + "The title array had length " + mDefaultListItemTitles.length
                    + " but the icon array had length " + mDefaultListItemIcons.length + "!");
        }
    }

    @Override
    public int getTitleResourceId() {
        return mTitleResource;
    }

    @Override
    public int getDescriptionResourceId() {
        return mDescriptionResource;
    }

    @Override
    public int getInputType() {
        return mInputType;
    }

    @Override
    public int getDisplayType() {
        return mDisplayType;
    }

    public ArrayList<SelectFromListWizardFragment.ListItem> getChoices(
            Context context, ArrayList<SelectFromListWizardFragment.ListItem> extraChoices) {
        ArrayList<SelectFromListWizardFragment.ListItem> choices = new ArrayList<>();
        if (extraChoices != null) {
            choices.addAll(extraChoices);
        }
        if (mDefaultListItemTitles != null) {
            // Find the largest priority of the items placed at the end of the list and place
            // default items after.
            int largestLastPriority = Integer.MIN_VALUE;
            if (extraChoices != null) {
                for (SelectFromListWizardFragment.ListItem item : extraChoices) {
                    if (item.getPinnedPosition()
                            == SelectFromListWizardFragment.PinnedListItem.LAST) {
                        SelectFromListWizardFragment.PinnedListItem pinnedItem =
                                (SelectFromListWizardFragment.PinnedListItem) item;
                        largestLastPriority = java.lang.Math.max(
                                largestLastPriority, pinnedItem.getPinnedPriority());
                    }
                }
            }
            for (int i = 0; i < mDefaultListItemTitles.length; i++) {
                choices.add(new SelectFromListWizardFragment.PinnedListItem(
                        context.getString(mDefaultListItemTitles[i]),
                        mDefaultListItemIcons == null ? 0 : mDefaultListItemIcons[i],
                        SelectFromListWizardFragment.PinnedListItem.LAST, i + largestLastPriority));
            }
        }
        return choices;
    }

    public FormPage create() {
        return FormPage.createTextInputForm(name());
    }

    public FormPage create(Intent intent) {
        if (mDisplayType != SimpleFormPageDisplayer.DISPLAY_TYPE_LOADING) {
            throw new IllegalArgumentException("Form page type " + name() + " had display type "
                    + mDisplayType + " but " + SimpleFormPageDisplayer.DISPLAY_TYPE_LOADING
                    + " expected!");
        }
        return FormPage.createIntentForm(name(), intent);

    }
}
