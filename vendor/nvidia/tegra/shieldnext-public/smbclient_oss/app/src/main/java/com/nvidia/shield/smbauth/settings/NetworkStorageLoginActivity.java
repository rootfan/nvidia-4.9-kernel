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

import android.app.Fragment;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.util.Log;
import android.widget.Toast;

import com.android.tv.settings.connectivity.SimpleFormPageDisplayer;
import com.android.tv.settings.connectivity.SimpleMultiPagedFormActivity;
import com.android.tv.settings.form.FormPage;
import com.android.tv.settings.form.FormPageResultListener;
import com.nvidia.shield.smbauth.R;
import com.nvidia.shield.smbauth.nas.SmbClient;
import com.nvidia.shield.smbauth.nas.SmbResult;

import java.util.ArrayList;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class NetworkStorageLoginActivity extends SimpleMultiPagedFormActivity {
    private static final String TAG = NetworkStorageLoginActivity.class.getSimpleName();

    public static final String EXTRAS_STORAGE_LIST = "com.nvidia.shield.smbauth.settings.NetworkStorageLoginActivity.server_list";
    public static final String EXTRAS_HOSTNAME = "com.nvidia.shield.smbauth.settings.NetworkStorageLoginActivity.hostname";
    public static final String EXTRAS_ADDRESS = "com.nvidia.shield.smbauth.settings.NetworkStorageLoginActivity.address";
    public static final String EXTRAS_DOMAIN = "com.nvidia.shield.smbauth.settings.NetworkStorageLoginActivity.domain";
    public static final String EXTRAS_USERNAME = "com.nvidia.shield.smbauth.settings.NetworkStorageLoginActivity.username";
    public static final String EXTRAS_PASSWORD = "com.nvidia.shield.smbauth.settings.NetworkStorageLoginActivity.password";
    public static final String EXTRAS_TARGET_SHARE = "com.nvidia.shield.smbauth.settings.NetworkStorageLoginActivity.target_share";
    public static final String EXTRAS_SHARES_LIST = "com.nvidia.shield.smbauth.settings.NetworkStorageLoginActivity.shares_list";
    public static final String EXTRAS_SMB_RESULT = "com.nvidia.shield.smbauth.settings.NetworkStorageLoginActivity.smb_result";
    public static final String EXTRAS_RECONNECT = "com.nvidia.shield.smbauth.settings.NetworkStorageLoginActivity.reconnect";

    private String mHostname;
    private String mAddress;
    private String mTargetShare;
    private String mDomain;
    private String mUsername;
    private String mPassword;
    private boolean mReconnectAfter;

    private FormPage mAddressPage;
    private FormPage mDomainPage;
    private FormPage mLoginTypePage;
    private FormPage mUserNamePage;
    private FormPage mPasswordPage;
    private NetworkStorageLoginFormPageType mCurrentPageType;

    public void parseDataFromMrl(String mrl) {
        //“workgroup;username:password@serveraddress”
        String domain = null;
        String name = null;
        String address = null;
        String username = null;
        String password = null;
        Pattern p = Pattern.compile("\\\\\\\\(\\S+)");
        Matcher matcher = p.matcher(mrl);
        if (matcher.find()) {
            String input = matcher.group(1);
            String host;
            String[] infos = input.split("@");
            if (infos.length == 1) {
                host = infos[0];
            } else {
                host = infos[1];

                input = infos[0];
                infos = input.split(";");
                if (infos.length > 1) {
                    domain = infos[0];
                    input = infos[1];
                } else {
                    input = infos[0];
                }

                infos = input.split(":");
                if (infos.length > 1) {
                    password = infos[1];
                }
                username = infos[0];
            }

            if (host.matches("(\\d+)\\.(\\d+)\\.(\\d+)\\.(\\d+)")) {
                address = host;
            } else {
                if (host.length() > 15) {
                    Log.w("NAS.WARNING", host + " exceeds 15-char netbios name limitation, trim down to " + host.substring(0, 15));
                    name = host.substring(0, 15);
                } else {
                    name = host;
                }
            }
        }

        mHostname = name;
        mAddress = address;
        mDomain = domain;
        mUsername = username;
        mPassword = password;

    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {

        SmbClient.initSmbConfig(getDir("home", MODE_PRIVATE));

        ArrayList<String> storageList = getIntent().getStringArrayListExtra(EXTRAS_STORAGE_LIST);
        mReconnectAfter = getIntent().getBooleanExtra(EXTRAS_RECONNECT, false);
        if (storageList != null) {
            if (storageList.size() == 0){
                addPage(NetworkStorageLoginFormPageType.ENTER_ADDRESS);
            } else {
                Bundle bundle = getIntent().getBundleExtra(storageList.get(0));

                mHostname = bundle.getString(EXTRAS_HOSTNAME);
                mAddress = bundle.getString(EXTRAS_ADDRESS);
                mDomain = bundle.getString(EXTRAS_DOMAIN);
                mUsername = bundle.getString(EXTRAS_USERNAME);
                mPassword = bundle.getString(EXTRAS_PASSWORD);
                if (mHostname == null && mAddress == null) {
                    addPage(NetworkStorageLoginFormPageType.ENTER_ADDRESS);
                } else if (mDomain == null) {
                    addPage(NetworkStorageLoginFormPageType.ENTER_DOMAIN);
                } else if (mUsername == null || mPassword == null) {
                    addPage(NetworkStorageLoginFormPageType.CHOOSE_LOGIN);
                } else {
                    connect();
                }
            }
        }
        super.onCreate(savedInstanceState);
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
    }

    @Override
    protected void displayPage(FormPage formPage, FormPageResultListener listener, boolean forward) {
        NetworkStorageLoginFormPageType formPageType = getFormPageType(formPage);
        Log.d(TAG, "displayPage: " + formPage.getTitle());
        mCurrentPageType = formPageType;
        Fragment fragment = displayPage(formPageType, mHostname == null ? mAddress : mHostname,
                null,
                null,
                getLastPage(formPageType),
                null,
                false, formPage, listener, forward,
                formPageType == NetworkStorageLoginFormPageType.ENTER_PASSWORD,
                formPageType == NetworkStorageLoginFormPageType.ENTER_DOMAIN ? getString(R.string.network_storage_login_example_domain) : null);

    }

    public boolean choiceChosen(FormPage formPage, int choiceResourceId) {
        return getString(choiceResourceId).equals(formPage.getDataSummary());
    }

    @Override
    public boolean onTextInputComplete(String text) {
        if (mCurrentPageType == NetworkStorageLoginFormPageType.ENTER_ADDRESS) {
            int index = text.lastIndexOf('\\');
            if (index != -1) {
                parseDataFromMrl(text.substring(0, index));
                mTargetShare = text.substring(index + 1);
                if (mHostname != null || mAddress != null) {
                    return super.onTextInputComplete(text);
                } else {
                    Toast.makeText(this, R.string.network_storage_login_address_wrong_format, Toast.LENGTH_SHORT).show();
                    return true;
                }
            } else {
                Toast.makeText(this, R.string.network_storage_login_address_wrong_format, Toast.LENGTH_SHORT).show();
                return true;
            }
        } else {
            return super.onTextInputComplete(text);
        }
    }

    public void sendResult(SmbResult result, ArrayList<String> shares){
        Intent intent = new Intent();
        intent.putExtra(EXTRAS_RECONNECT, mReconnectAfter);
        intent.putExtra(EXTRAS_SMB_RESULT, result.ordinal());
        intent.putExtra(EXTRAS_USERNAME, mUsername);
        intent.putExtra(EXTRAS_PASSWORD, mPassword);
        intent.putExtra(EXTRAS_DOMAIN, mDomain);
        intent.putExtra(EXTRAS_HOSTNAME, mHostname);
        intent.putExtra(EXTRAS_ADDRESS, mAddress);
        intent.putExtra(EXTRAS_TARGET_SHARE, mTargetShare);
        intent.putStringArrayListExtra(EXTRAS_SHARES_LIST, shares);
        if (result != SmbResult.SUCCESS) {
            setResult(RESULT_CANCELED, intent);
        } else {
            setResult(RESULT_OK, intent);
        }
        finish();
    }

    private void connect() {
        new GetSharesTask().execute();
    }

    @Override
    protected boolean onPageComplete(FormPage formPage) {
        NetworkStorageLoginFormPageType formPageType = getFormPageType(formPage);
        Log.d(TAG, "onPageComplete: " + formPageType);
        clearAfter(formPage);

        if (formPageType.getDisplayType() == SimpleFormPageDisplayer.DISPLAY_TYPE_LOADING) {
            removePage(formPage);
        }

        switch (formPageType) {
            case CHOOSE_LOGIN:
            {
                mLoginTypePage = formPage;
                if (choiceChosen(formPage, R.string.network_storage_login_as_guest)) {
                    mUsername = mPassword = "Guest";
                    connect();
                } else {
                    addPage(NetworkStorageLoginFormPageType.ENTER_USERNAME.create());
                }
            }
                break;
            case ENTER_USERNAME:
            {
                mUserNamePage = formPage;
                mUsername = formPage.getDataSummary();
                addPage(NetworkStorageLoginFormPageType.ENTER_PASSWORD);
            }
                break;
            case ENTER_PASSWORD:
            {
                mPasswordPage = formPage;
                mPassword = formPage.getDataSummary();
                connect();
            }
                break;
            case ENTER_ADDRESS:
            {
                mAddressPage = formPage;
                if (mDomain != null) {
                    if (mUsername != null && mPassword != null) {
                        connect();
                        setResult(RESULT_OK);
                    } else {
                        addPage(NetworkStorageLoginFormPageType.CHOOSE_LOGIN);
                    }
                } else {
                    addPage(NetworkStorageLoginFormPageType.ENTER_DOMAIN);
                }
            }
                break;
            case ENTER_DOMAIN:
            {
                mDomainPage = formPage;
                mDomain = formPage.getDataSummary();
                if (mUsername != null && mPassword != null) {
                    connect();
                } else {
                    addPage(NetworkStorageLoginFormPageType.CHOOSE_LOGIN);
                }
            }
                break;
        }
        return true;
    }
    public void addPage(NetworkStorageLoginFormPageType formPageType) {
        FormPage formPage = formPageType.create();
        addPage(formPage);
    }

    private FormPage getLastPage(NetworkStorageLoginFormPageType formPageType) {
        switch (formPageType) {
            case CHOOSE_LOGIN:
                return mLoginTypePage;
            case ENTER_PASSWORD:
                return mPasswordPage;
            case ENTER_USERNAME:
                return mUserNamePage;
            case ENTER_ADDRESS:
                return mAddressPage;
            case ENTER_DOMAIN:
                return mDomainPage;
            default:
                return null;
        }
    }

    protected NetworkStorageLoginFormPageType getFormPageType(FormPage formPage) {
        return NetworkStorageLoginFormPageType.valueOf(formPage.getTitle());
    }

    private class GetSharesTask extends AsyncTask<Void, Void, ArrayList<String>> {
        private SmbResult mResult;

        @Override
        protected ArrayList<String> doInBackground(Void... voids) {

            ArrayList<String> list = new ArrayList<>();
            mResult = SmbClient.getShares(mAddress == null ? mHostname : mAddress, mDomain, mUsername, mPassword, list);
            Log.d(TAG, "getShares result is " + mResult);

            return list;
        }

        @Override
        protected void onPostExecute(ArrayList<String> shares) {
            sendResult(mResult, shares);
        }
    }

}
