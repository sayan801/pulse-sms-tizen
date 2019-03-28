<template>
    <div id="app">

      <!-- Content Area -->
      <div id="content">
          <main class="mdl-layout__content">
              <router-view></router-view>
          </main>
      </div> <!-- End Content Area -->

        <!-- Loading splash page -->
        <!-- <transition name="splash-fade">
            <splash v-if="$store.state.loading"></splash>
        </transition> -->
        <Snackbar />
        <ImageViewer />
    </div>
</template>

<script>

import Vue from 'vue'
import { i18n } from '@/utils'

import '@/lib/sjcl.js'
import '@/lib/hmacsha1.js'

import { Util, Crypto, Api, MediaLoader, SessionCache, Platform } from '@/utils'

import Conversations from '@/components/Conversations/'
import Snackbar from '@/components/Snackbar.vue'
import ImageViewer from '@/components/ImageViewer.vue'

export default {
    name: 'app',

    beforeCreate () {
        this.$store.commit('title', "Pulse SMS");

        // If logged in (account_id) then setup crypto
        if(this.$store.state.account_id != '')
            Crypto.setupAes();
        else
            this.$router.push('login');

        let accountId = this.$store.state.account_id;
        let hash = this.$store.state.hash;
        let salt = this.$store.state.salt;
    },

    mounted () { // Add window event listener

        this.calculateHour(); // Calculate the next hour (for day/night theme)
        this.updateBodyClass(this.theme_str, ""); // Enables global theme

        // Handle resizing for left margin size
        window.addEventListener('resize', this.handleResize)
        this.handleResize(); // Get initial margin size

        // Tizen events
        window.addEventListener('tizenhwkey', this.handleBackButton)
        window.addEventListener('rotarydetent', this.handleRotary)
        window.addEventListener('blur', this.pause)
        window.addEventListener('focus', this.resume)

        // Setup firebase
        Util.firebaseConfig();

        // Construct colors object from saved global theme
        const colors = {
            'default': this.$store.state.theme_global_default,
            'dark': this.$store.state.theme_global_dark,
            'accent': this.$store.state.theme_global_accent,
        };

        // Commit them to current application colors
        this.$store.commit('colors', colors);

        // If logged in start app
        if (this.$store.state.account_id != '') {
            this.applicationStart();
        } else { // Otherwise, add listener for start-app event
                 // This allows for another part of the app to setup parts of the app
                 // Which may have unmet requirements (such as login)
            this.$store.state.msgbus.$on('start-app', this.applicationStart);
            this.mount_view = true;
        }

        // Setup global button listeners
        this.$store.state.msgbus.$on('settings-btn', () => this.$router.push('/settings'));
        this.$store.state.msgbus.$on('account-btn', () => this.$router.push('/account'));
        this.$store.state.msgbus.$on('help-feedback-btn', () => this.$router.push('/help_feedback'));
        this.$store.state.msgbus.$on('logout-btn', this.logout);

        // Set toolbar color with materialColorChange animiation
        const toolbar = this.$el.querySelector("#toolbar");
        Util.materialColorChange(toolbar, this.theme_toolbar);
    },

    beforeDestroy () { // Remove event listeners
        window.removeEventListener('resize', this.handleResize)
        window.removeEventListener('tizenhwkey', this.handleBackButton)
        window.removeEventListener('rotarydetent', this.handleRotary)
        window.removeEventListener('pause', this.pause)
        window.removeEventListener('resume', this.resume)

        this.$store.state.msgbus.$off('start-app');
        this.$store.state.msgbus.$off('settings-btn');
        this.$store.state.msgbus.$off('logout-btn');

        this.mm.closeWebSocket();
    },

    data () {
        return {
            margin: 0,
            loading: this.$store.state.loading,
            mm: null,
            toolbar_color: this.$store.state.theme_global_default,
            hour: null,
        }
    },

    methods: {

        /**
         * Application start
         * Used to allow for "late starts" such as after a login
         * without refreshing page to remount app.
         * Contains app components that require account to run.
         */
        applicationStart () {
            // Setup the API (Open websocket)
            this.mm = new Api();

            // Setup and store the medialoader (MMS)
            this.$store.commit('media_loader', new MediaLoader());

            setTimeout(() => {
                // Fetch contacts for cache
                Api.fetchContacts().then((resp) => this.processContacts(resp));

                // Grab user settings from server and store in local storage
                Api.fetchSettings();
            }, 1500);

            // Interval check to maintain socket
            setInterval(() => {
                const last_ping = this.$store.state.last_ping;

                // Ignore if ping is sitll none (usually just starting up)
                if (last_ping == null)
                    return;

                // If last ping is within 15 seconds, ignore
                if (last_ping > (Date.now() / 1000 >> 0) - 15)
                    return;

                // Else, open new API and force refresh
                this.mm.closeWebSocket()
                this.mm = new Api();
                this.mm.has_diconnected = true; // Initialize new api with has disconnected

                this.calculateHour();

                // TODO slack like reconnection process

            }, 15 * 1000);
        },

        /**
         * Calculates margin size on window resize
         * effectively creating a dynamic left-side whitespace
         */
        handleResize () { // Handle resize. Toggles full/mini theme
            const MAIN_CONTENT_SIZE = 950;
            const width = document.documentElement.clientWidth;
            let margin = 0;

            // If width is less than 750, close sidebar
            if (width > 750) {
                this.$store.commit('full_theme', true);
            } else {
                this.$store.commit('full_theme', false);
            }

            // Handles left side offset
            // Calculates width based on the main content size of 950
            if (width > MAIN_CONTENT_SIZE) {
                margin = (width - MAIN_CONTENT_SIZE) / 2;
            }

            // Set margin
            this.margin = margin
            this.$store.state.msgbus.$emit('newMargin', margin);
        },

        /**
         * Tizen supports a hardware back button.
         */
        handleBackButton (button) {
            switch(button.keyName) {
                case 'back':
                    if (this.$route.name.indexOf('conversations-list') > -1) {
                        tizen.application.getCurrentApplication().exit();
                    } else {
                        this.$router.push({ name: 'conversations-list'});
                        Vue.nextTick(() => {
                            Util.scrollToTop();
                        });
                    }
                    break;
            }
        },

        /**
         * Scrolling with the crown causes a rotary event
         */
        handleRotary (event) {
            switch(event.detail.direction) {
                case 'CW':
                    Util.rotaryEventDown()
                    break;
                case 'CCW':
                    Util.rotaryEventUp()
                    break;
            }
        },

        /**
         * Tizen callback for the app entering the background
         */
        pause () {
            // Close socket
            if (this.mm != null) {
                this.mm.closeWebSocket();
            }
        },

        /**
         * Tizen callback for the app entering the foreground
         */
        resume () {
            this.$store.state.msgbus.$emit("refresh-btn");

            if (this.mm != null) {
                const _this = this;
                setTimeout(() => {
                    // Re-open socket
                    _this.mm.openWebSocket();
                }, 1000)
            }
        },

        /**
         * Updates theme (toolbar color)
         * When toolbar theme is enabled
         * @param color - rgb/hex color string.
         */
        updateTheme (color) {
            // Ignore if toolbar theme is false
            if (!this.$store.state.theme_apply_appbar_color)
                return false;

            this.toolbar_color = color;
        },

        /**
         * Handle logout
         * Removes sensative data, clears local storage,
         * and closes websocket
         */
        logout () {

            // Remove sensative data
            this.$store.commit('account_id', "");
            this.$store.commit('hash', "");
            this.$store.commit('salt', "");
            this.$store.commit('aes', "");
            this.$store.commit('clearContacts', {});

            SessionCache.invalidateAllConversations();
            SessionCache.invalidateAllMessages();

            // Clear local storage (browser)
            window.localStorage.clear();

            // Close socket
            this.mm.closeWebSocket();

            Util.snackbar("You've been logged out");

            this.$router.push('login');
        },

        /**
         * updates body class.
         * Removes from class, adds to class
         * @param to - new class
         * @param from  - old class
         */
        updateBodyClass (to, from) {
            const body = this.$el.parentElement; // select body
            // Add and remove classes
            const classes = body.className.replace(from, "")
            body.className = classes + " " + to;
        },

        /**
         * Sets current hour, ever hour on the hour.
         */
        calculateHour () {

            // Determines ms to the next hour
            const nextHour = (60 - new Date().getMinutes()) * 60 * 1000
            this.hour = new Date().getHours(); // Get current hour

            setTimeout(() => { // Rerun function at the next hour
                this.calculateHour()
            }, nextHour + 2000);
        },

        /**
         * Process contacts received from server
         * Saves contacts in contacts array
         * Also starts recipient processing
         * @param data, contact request result
         */
        processContacts(response) {
            const contacts_cache = [];

            for (let contact of response) {
                // Generate contact and add to cache list
                let contact_data = Util.generateContact(
                    Util.createIdMatcher(contact.phone_number),
                    contact.name,
                    contact.phone_number,
                    false, // mute
                    false, // private_notification
                    contact.color,
                    contact.color_accent,
                    null, // darker
                    null // lighter
                );

                contacts_cache.push(contact_data);
            }

            this.$store.commit('contacts', contacts_cache);
        },

        openUrl (url) {
            window.open(url, '_blank');
        }
    },

    computed: {
        icon_class () {
            return {
                'logo': this.full_theme && !this.$store.state.theme_apply_appbar_color,
                'logo_dark': this.full_theme && this.$store.state.theme_apply_appbar_color,
                'menu_toggle': !this.full_theme && !this.$store.state.theme_apply_appbar_color,
                'menu_toggle_dark': !this.full_theme && this.$store.state.theme_apply_appbar_color,
            }
        },

        full_theme () { // Full_theme state
            return this.$store.state.full_theme;
        },

        theme_str () {
            const theme = this.$store.state.theme_base;

            // If day/night, return dark/light
            if (theme == "day_night")
                return this.is_night ? "dark" : "";

            if (theme == "black")
                return 'dark black';

            return theme; // Otherwise return stored theme
        },

        is_night () { // If "night" (between 20 and 7)
            return this.hour < 7 || this.hour >= 20 ? true : false;
        },

        theme_toolbar () { // Determine toolbar color
            if (!this.$store.state.theme_apply_appbar_color)  // If not color toolbar
                return this.default_toolbar_color;

            if (this.$store.state.theme_use_global) // If use global
                return this.$store.state.theme_global_default;

            return this.toolbar_color;
        },

        default_toolbar_color () { // Determine default colors
            if (!this.$store.state.theme_apply_appbar_color) {
                if (this.theme_str.indexOf('black') >= 0) {
                    return "#000000";
                } else if (this.theme_str.indexOf('dark') >= 0) {
                    return "#202b30";
                } else {
                    return "#FFFFFF";
                }
            } else if (this.$store.state.theme_global_default) {
                return this.$store.state.theme_global_default;
            } else {
                return "#1775D2";
            }
        },

        text_color () { // Determines toolbar text color
            if (this.$store.state.theme_apply_appbar_color)
                return "#fff";
        }
    },
    watch: {
        '$store.state.colors_default' (to) { // Handle theme changes
            this.updateTheme(to);
        },
        'theme_str' (to, from) { // Handles updating the body class
            this.updateBodyClass(to, from)
        },
        'theme_toolbar' (to, from) { // Handle toolbar color change
            Vue.nextTick(() => {
                const toolbar = this.$el.querySelector("#toolbar");
                Util.materialColorChange(toolbar, to);
            })
        },
        '$store.state.title' (to) {
            if (to.length > 0) {
                document.title = to;
            } else {
                document.title = "Pulse SMS";
            }
        }

    },
    components: {
        Conversations,
        Snackbar,
        ImageViewer
    }
}
</script>

<style lang="scss">

    @import "./assets/scss/material.teal-orange.min.css";
    @import "./assets/scss/_vars.scss";

    body {
        margin: auto;
        margin-left: 0;
        color: #202020;
        background-color: $bg-light;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol";
        font-size: 24px;
        padding: 0 !important;
        margin-bottom: 0 !important;
        -webkit-user-select: none;
        -moz-user-select: none;
        -ms-user-select: none;
        user-select: none;
        font-smooth: always;
        -webkit-font-smoothing: antialiased;
        -moz-osx-font-smoothing: grayscale;
    }

    #wrapper {
        transition: ease-in-out margin-left $anim-time;

    }

    #content {
        transition: ease-in-out margin-left $anim-time;
        margin-left: 0px;
        margin-right: 0px;
        width: 100%;
        height: 100%;
        vertical-align: top;
    }

    .mdl-layout__content {
        width: 100%;
        height: 100%;
        position: relative;

        .page-content {
            bottom: 0;
            margin: auto;
            margin-bottom: 54px;
            margin-top: 12px;
            overflow: hidden;

            @media screen and (min-width: 720px) {
                & {
                    max-width: 720px;
                    padding: 16px;
                }
            }

            @media screen and (min-width: 600px) {
                & {
                    max-width: 600px;
                    padding: 16px;
                }
            }
        }
    }

    .shadow {
        box-shadow: 0px 2px 2px 0 rgba(0, 0, 0, 0.25);
    }


    #refresh-button.rotate {
        transition: transform .3s ease-in;
        transform: rotate(360deg);
    }

    .list-enter-active, .list-leave-active {
        transition: all .3s;
    }
    .list-enter, .list-leave-to /* .list-leave-active below version 2.1.8 */ {
        opacity: 0;
        transform: translateX(30px);
    }

    .link-sent {
        color: black;
    }

    .link-received {
        color: white;
    }

    body.dark {
        background-color: $bg-dark;
        color: #fff;

        .mdl-progress > .bufferbar {
            background-image: linear-gradient(to right,rgba(55, 66, 72,.7),rgba(55, 66, 72,.7)),
                linear-gradient(to right,rgb(33,150,243),rgb(33,150,243));
        }

        #toolbar {
            border-bottom: solid 1px #ca2100;
            background-color: $bg-darker;
            border-color: #202b30;
        }

        #logo .icon {
            &.logo {
                background: url(assets/images/vector/pulse-dark.svg) 0 0 no-repeat !important;
            }

            &.menu_toggle {
                background: url(assets/images/vector/menu_toggle-dark.svg) 0 0 no-repeat !important;
            }

        }

        .mdl-color-text--grey-900 {
            color: #fff !important;
        }

        .mdl-color-text--grey-600 {
            color: rgba(255,255,255,.77) !important;
        }

        .link-sent {
            color: white;
        }
    }

    body.black {
        background-color: $bg-black;

        #toolbar {
            border-bottom: solid 1px #000000;
            background-color: $bg-black;
            border-color: #000000;
        }
    }

    .transition span.animator {
        position: absolute;
        height: 100%;
        width: 100%;
        top: 0;
        left: 0;
        overflow: hidden;

        span:first-of-type {
            display: block;
            position: absolute;
            top: -50%;
            width: 200%;
            height: 200%;
            margin-left: -50%;
            border-radius: 50px;
            opacity: 0;
            z-index: 3;
            animation: ripple .5s ease-out forwards;
        }
    }

    @keyframes ripple {
        0% {
            transform: scaleX(0);
        }
        70% {
            transform: scaleX(0.5);
        }
        100% {
            opacity: 1;
            transform: scaleX(1);
        }
    }

</style>
