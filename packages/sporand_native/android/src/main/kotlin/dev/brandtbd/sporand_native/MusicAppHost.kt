package dev.brandtbd.sporand_native

import android.app.SearchManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.provider.MediaStore

/**
 * Hands the DJ's cue (external_player / BYOP, addendum A2.2) to whatever
 * music app the DJ uses. The app never plays or streams the song itself.
 *
 * `INTENT_ACTION_MEDIA_PLAY_FROM_SEARCH` with the "song" focus
 * (`Audio.Media.ENTRY_CONTENT_TYPE`) plus title, artist and a free-text
 * query, as documented for voice-search requests to media apps. Starting an
 * implicit intent needs no `<queries>` entry; an app-less device throws
 * `ActivityNotFoundException`, reported as `false`.
 */
class MusicAppHost(private val context: Context) : MusicAppApi {
    override fun playFromSearch(search: MusicSearchMessage): Boolean {
        val intent = Intent(MediaStore.INTENT_ACTION_MEDIA_PLAY_FROM_SEARCH).apply {
            putExtra(MediaStore.EXTRA_MEDIA_FOCUS, MediaStore.Audio.Media.ENTRY_CONTENT_TYPE)
            putExtra(MediaStore.EXTRA_MEDIA_TITLE, search.title)
            putExtra(MediaStore.EXTRA_MEDIA_ARTIST, search.artist)
            putExtra(SearchManager.QUERY, search.query)
            // Started from the application context, outside an activity task.
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            context.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }
    }
}
