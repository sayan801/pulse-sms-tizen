<template>
    <div id="login-pane" v-mdl>
        <div>
            <p v-if="error" class="error">{{ $t('login.error') }}</p>
            <form>
                <div class="mdl-textfield mdl-js-textfield">
                    <input class="mdl-textfield__input" type="email" placeholder="Email Address" v-model="username" autofocus/>
                </div>
                <div class="mdl-textfield mdl-js-textfield">
                    <input class="mdl-textfield__input" type="text" placeholder="Password" v-model="password" @keyup.enter="doLogin"/>
                </div>
            </form>
        </div>
        <button class="mdl-button mdl-button--colored mdl-js-button" :disabled="loading" id="login" @click="doLogin">{{ $t('login.login') }}</button>
    </div>
</template>

<script>

import '@/lib/sjcl.js'
import '@/lib/hmacsha1.js'
import Vue from 'vue'
import { Crypto, Url, Api } from '@/utils/'
import Spinner from '@/components/Spinner.vue'


export default {
    name: 'login',

    mounted () {
        if (this.$store.state.account_id != '')
            return this.$router.push({ name: 'conversations-list'});

        this.$store.commit("loading", false);
        this.$store.commit('title', this.title);
    },

    data () {
        return {
            title: "",
            username: '',
            password: '',
            loading: false,
            error: false,
        }
    },

    methods: {
        doLogin() {

            if (this.username == '' || this.password == '')
                return;

            this.error = false;
            this.loading = true;

            Api.login(this.username, this.password)
                .then((data) => this.handleData(data.data))
                .catch((data) => this.handleError(data));
        },

        handleData (data) {
            this.error = false;

            // Create hash
            let derived_key = sjcl.misc.pbkdf2(this.password, data.salt2, 10000, 256, hmacSHA1);
            let base64_hash = sjcl.codec.base64.fromBits(derived_key);

            // Save data
            this.$store.commit('account_id', data.account_id);
            this.$store.commit('hash', base64_hash);
            this.$store.commit('salt', data.salt1);

            Crypto.setupAes(); // Setup aes for session

            this.loading = false;

            // Start app
            this.$store.state.msgbus.$emit('start-app');

            this.$router.push({ name: 'conversations-list'});
        },

        handleError(data) {
            this.password = "";
            this.error = true;
            this.loading = false;
        }
    },

    components: {
        Spinner
    }
}
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style lang="scss" scoped>
    @import "../assets/scss/_vars.scss";

    .mdl-textfield__input, .mdl-textfield__label {
        text-align: center;
        font-size: 22px;
    }

    .mdl-card__title-text {
        text-align: center;
        margin: auto;
    }

    #login-pane {
        margin: 10px auto;
        text-align: center;
        font-size: 24px;
    }

    .error {
        color: rgb(255,64,129);
    }
</style>
